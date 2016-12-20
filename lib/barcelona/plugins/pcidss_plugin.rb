module Barcelona
  module Plugins
    class PcidssPlugin < Base
      class OssecBuilder < CloudFormation::Builder
        delegate :district, to: :stack

        def manager_user_data
          user_data = InstanceUserData.new
          user_data.packages += ["docker"]
          docker_command = [
            "docker", "run", "-d",
            "-p 1514:1514/udp",
            "-p 1515:1515",
            "-v /ossec_mnt:/var/ossec/data",
            "--name ossec",
            "quay.io/degica/barcelona-wazuh"
          ].join(" ")
          user_data.run_commands += [
            "set -e",
            "service docker start",
#            docker_command
          ]
          user_data
        end

        def build_resources
          private_hosted_zone = district.aws.route53.get_hosted_zone(id: district.private_hosted_zone_id).hosted_zone
          add_resource("AWS::EC2::Instance", "OSSECManager") do |j|
            j.InstanceType "t2.small"
            j.ImageId "ami-1a15c77b"
            j.KeyName "kkajihiro" # ERASEME
            j.UserData manager_user_data.build
            j.NetworkInterfaces [
              {
                "AssociatePublicIpAddress" => true,
                "DeviceIndex" => 0,
                "SubnetId" => district.stack_resources["SubnetDmz1"],
                "GroupSet" => [ref("OSSECManagerSG")]
              }
            ]
            j.Tags [
              tag("Name", join("-", cf_stack_name, "ossec-manager")),
              tag("barcelona", district.name),
              tag("barcelona-role", "pcidss"),
            ]
          end

          add_resource("AWS::Route53::RecordSet", "OSSECManagerRecordSet") do |j|
            j.HostedZoneId district.private_hosted_zone_id
            j.Name ["ossec-manager",
                    district.name,
                    private_hosted_zone.name].join(".")
            j.TTL 60
            j.Type "A"
            j.ResourceRecords [get_attr("OSSECManager", "PrivateIp")]
          end

          add_resource("AWS::EC2::SecurityGroup", "OSSECManagerSG") do |j|
              j.GroupDescription "SG for OSSEC Manager Instance"
              j.VpcId district.vpc_id
              j.SecurityGroupIngress [
                {
                  "IpProtocol" => "icmp",
                  "FromPort" => -1,
                  "ToPort" => -1,
                  "CidrIp" => district.cidr_block
                },
                # OSSEC manager
                {
                  "IpProtocol" => "udp",
                  "FromPort" => 1514,
                  "ToPort" => 1514,
                  "SourceSecurityGroupId" => district.instance_security_group
                },
                # OSSEC authd
                {
                  "IpProtocol" => "tcp",
                  "FromPort" => 1515,
                  "ToPort" => 1515,
                  "SourceSecurityGroupId" => district.instance_security_group
                }
              ]
              j.Tags [
                tag("barcelona", district.name),
                tag("barcelona-role", "pcidss")
              ]
          end

          add_resource("AWS::Elasticsearch::Domain", "Elasticsearch") do |j|
            j.ElasticsearchClusterConfig do |j|
              j.InstanceCount 1
              j.InstanceType "t2.micro.elasticsearch"
            end

            j.EBSOptions do |j|
              j.EBSEnabled true
              j.VolumeSize 10
              j.VolumeType "gp2"
            end

            j.AccessPolicies(
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Sid" => "",
                  "Effect" => "Allow",
                  "Principal" => {
                    "AWS" => "*"
                  },
                  "Action" => "es:*",
                  "Condition" => {
                    "IpAddress" => {
                      "aws:SourceIp" => [
                        district.cidr_block
                      ]
                    }
                  },
                  "Resource" => "*"
                }
              ]
            )
            j.ElasticsearchVersion "2.3"
            j.Tags [
              tag("barcelona", district.name)
            ]
          end

          add_resource("AWS::Route53::RecordSet", "ElasticsearchRecordSet") do |j|
            j.HostedZoneId district.private_hosted_zone_id
            j.Name ["ossec-es",
                    district.name,
                    private_hosted_zone.name].join(".")
            j.TTL 300
            j.Type "CNAME"
            j.ResourceRecords [get_attr("Elasticsearch", "DomainEndpoint")]
          end
        end
      end

      class OssecStack < CloudFormation::Stack
        attr_accessor :district

        def initialize(district)
          stack_name = "#{district.name}-ossec"
          @district = district
          super(stack_name)
        end

        def build
          super do |builder|
            builder.add_builder OssecBuilder.new(self, options)
          end
        end
      end

      SYSTEM_PACKAGES = ["clamav", "clamav-update", "tmpwatch", "fail2ban"]
      # Exclude different file systems such as /proc and /dev (-xdev)
      # Files that have changed within a day (-mtime -1)
      SCAN_COMMAND = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

      def run_commands
        [
          # Enable freshclam configuration
          "sed -i 's/^Example$//g' /etc/freshclam.conf",
          "sed -i 's/^FRESHCLAM_DELAY=disabled-warn.*$//g' /etc/sysconfig/freshclam",

          # Daily full file system scan
          "echo '0 0 * * * root #{SCAN_COMMAND}' > /etc/cron.d/clamscan",
          "service crond restart",

          # fail2ban configurations
          "echo '[DEFAULT]' > /etc/fail2ban/jail.local",
          "echo 'bantime = 1800' >> /etc/fail2ban/jail.local",
          "service fail2ban restart",

          # SSH session timeout
          "echo 'TMOUT=900 && readonly TMOUT && export TMOUT' > /etc/profile.d/tmout.sh",

          # OSSEC Agent configuration
          "yum install -y ossec-hids-agent",
          "sed -i 's/<server-ip>.*<\/server-ip>/<server-hostname>ossec-manager.#{district.name}.bcn<\/server-hostname>/g' /var/ossec/etc/ossec.conf",
          "/var/ossec/bin/agent-auth -m ossec-manager.#{district.name}.bcn",
          "/var/ossec/bin/ossec-control restart"
        ]
      end

      def on_container_instance_user_data(_instance, user_data)
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += run_commands
        user_data.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<EOS)
[wazuh]
name = WAZUH OSSEC Repository - www.wazuh.com
baseurl = http://ossec.wazuh.com/el/7/x86_64
gpgcheck = 1
gpgkey = http://ossec.wazuh.com/key/RPM-GPG-KEY-OSSEC
enabled = 1
EOS
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_server = template["BastionServer"]
        return template if bastion_server.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_server["Properties"]["UserData"])
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += run_commands
        user_data.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<EOS)
[wazuh]
name = WAZUH OSSEC Repository - www.wazuh.com
baseurl = http://ossec.wazuh.com/el/7/x86_64
gpgcheck = 1
gpgkey = http://ossec.wazuh.com/key/RPM-GPG-KEY-OSSEC
enabled = 1
EOS
        bastion_server["Properties"]["UserData"] = user_data.build
        template
      end

      def stack_executor
        stack = OssecStack.new(district)
        CloudFormation::Executor.new(stack, district.aws.cloudformation)
      end

      def on_created(_, args)
        stack_executor.create_or_update
      end

      def on_updated(_, args)
        stack_executor.create_or_update
      end

      def on_destroyed(_, _)
        stack_executor.delete
      end
    end
  end
end
