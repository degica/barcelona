module Barcelona
  module Plugins
    class PcidssPlugin < Base
      class OssecBuilder < CloudFormation::Builder
        delegate :district, to: :stack

        def manager_user_data
          user_data = InstanceUserData.new
          user_data.packages += ["docker", "jq"]
          docker_command = [
            "docker", "run", "-d",
            "-p 1514:1514/udp",
            "-p 1515:1515",
            "-v /ossec_mnt:/var/ossec/data",
            "-e ELASTICSEARCH_URL=ossec-es.#{district.name}.bcn",
            "--name ossec",
            "quay.io/degica/barcelona-ossec"
          ].join(" ")
          user_data.run_commands += [
            "set -ex",
            "service docker start",
            "volume_id=$(aws ec2 describe-volumes --region ap-northeast-1 --filters Name=tag-key,Values=ossec-manager-volume | jq -r '.Volumes[0].VolumeId')",
            "instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
            "aws ec2 attach-volume --region ap-northeast-1 --volume-id $volume_id --instance-id $instance_id --device /dev/xvdh",
            "sleep 60",
            "[[ $(file -s /dev/xvdh) =~ :\\ data$ ]] && mkfs -t ext4 /dev/xvdh",
            "mkdir /ossec_mnt",
            "mount /dev/xvdh /ossec_mnt"
#            docker_command
          ]
          user_data
        end

        def build_resources
          private_hosted_zone = district.aws.route53.get_hosted_zone(id: district.private_hosted_zone_id).hosted_zone

          add_resource("AWS::EC2::Volume", "OSSECManagerVolume") do |j|
            j.AvailabilityZone "ap-northeast-1a"
            j.Encrypted true
            j.Size 8
            j.Tags [
              tag("ossec-manager-volume"),
              tag("barcelona", district.name),
              tag("barcelona-role", "pcidss"),
            ]
          end

          add_resource("AWS::AutoScaling::LaunchConfiguration",
                       "OSSECManagerLaunchConfiguration") do |j|
            j.IamInstanceProfile ref("OSSECManagerInstanceProfile")
            j.ImageId "ami-1a15c77b"
            j.InstanceType "t2.small"
            j.AssociatePublicIpAddress true
            j.KeyName "kkajihiro" # ERASEME
            j.SecurityGroups [ref("OSSECManagerSG")]
            j.UserData manager_user_data.build
            j.EbsOptimized false
            j.BlockDeviceMappings [
              {
                "DeviceName" => "/dev/xvda",
                "Ebs" => {
                  "DeleteOnTermination" => true,
                  "VolumeSize" => 8,
                  "VolumeType" => "gp2"
                }
              },
            ]
          end

          add_resource("AWS::IAM::Role", "OSSECManagerRole") do |j|
            j.AssumeRolePolicyDocument do |j|
              j.Version "2012-10-17"
              j.Statement [
                {
                  "Effect" => "Allow",
                  "Principal" => {
                    "Service" => ["ec2.amazonaws.com"]
                  },
                  "Action" => ["sts:AssumeRole"]
                }
              ]
            end
            j.Path "/"
            j.Policies [
              {
                "PolicyName" => "barcelona-ecs-container-instance-role",
                "PolicyDocument" => {
                  "Version" => "2012-10-17",
                  "Statement" => [
                    {
                      "Effect" => "Allow",
                      "Action" => [
                        "ec2:DescribeVolumes",
                        "ec2:AttachVolume",
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:DescribeLogStreams",
                        "logs:PutLogEvents",
                      ],
                      "Resource" => ["*"]
                    }
                  ]
                }
              }
            ]
          end

          add_resource("AWS::IAM::InstanceProfile", "OSSECManagerInstanceProfile") do |j|
            j.Path "/"
            j.Roles [ref("OSSECManagerRole")]
          end

          add_resource("AWS::AutoScaling::AutoScalingGroup", "OSSECManagerASG") do |j|
            j.DesiredCapacity 1
            j.HealthCheckGracePeriod 0
            j.MaxSize 1
            j.MinSize 1
            j.HealthCheckType "EC2"
            j.LaunchConfigurationName ref("OSSECManagerLaunchConfiguration")
            j.VPCZoneIdentifier [district.stack_resources["SubnetDmz1"]]
            j.Tags [
              {
                "Key" => "Name",
                "Value" => join("-", cf_stack_name, "manager"),
                "PropagateAtLaunch" => true
              },
              {
                "Key" => "barcelona",
                "Value" => district.name,
                "PropagateAtLaunch" => true
              },
              {
                "Key" => "barcelona-role",
                "Value" => "pcidss",
                "PropagateAtLaunch" => true
              }
            ]
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
                },
                {
                  "Effect" => "Allow",
                  "Principal" => {
                    "AWS" => [
                      "822761295011"
                    ]
                  },
                  "Action" => [
                    "es:*"
                  ],
                  "Resource" => "arn:aws:es:ap-northeast-1:822761295011:domain/test-di-elasti-tq9xmobctins/*"
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
