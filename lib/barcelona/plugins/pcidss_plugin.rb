# PCIDSS plugin
### This plugin adds the following resources/configuration to a district
### - Installs Clam AV in all instances. Scans run every day.
### - Installs fail2ban in all instances
### - Installs OSSEC agent in all instances
### - Adds OSSEC manager in the private subnet
###
### Currently this plugin works only in Tokyo (ap-notheast-1) region

module Barcelona
  module Plugins
    class PcidssBuilder < CloudFormation::Builder
      delegate :district, to: :stack

      SCAN_COMMAND = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

      def manager_user_data
        user_data = InstanceUserData.new
        user_data.packages += ["docker", "jq", "awslogs", "tmpwatch", "yum-cron"]

        change_batch = {
          "Changes" => [
            {
              "Action" => "UPSERT",
              "ResourceRecordSet" => {
                "Name" => "ossec-manager.#{district.name}.bcn",
                "Type" => "A",
                "TTL" => 60,
                "ResourceRecords" => [
                  "Value" => "{private_ip}"
                ]
              }
            }
          ]
        }.to_json

        user_data.run_commands += [
          "set -ex",
          'echo "exclude=docker" >> /etc/yum.conf',
          'sed -i -e "s/^update_cmd = .*/update_cmd = security/" /etc/yum/yum-cron.conf',
          'sed -i -e "s/^apply_updates = .*/apply_updates = yes/" /etc/yum/yum-cron.conf',
          "service yum-cron start",

          "amazon-linux-extras install -y epel",
          "yum install -y clamav clamav-update",

          # Install AWS Inspector agent
          "curl https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install | bash",

          # imdsv2
          'IMDSTOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`',

          # awslogs
          'ec2_id=$(curl -H "X-aws-ec2-metadata-token: $IMDSTOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)',
          'sed -i -e "s/{ec2_id}/$ec2_id/g" /etc/awslogs/awslogs.conf',
          'sed -i -e "s/us-east-1/'+district.region+'/g" /etc/awslogs/awscli.conf',
          "systemctl start awslogsd",

          # Enable freshclam configuration
          "sed -i 's/^Example$//g' /etc/freshclam.conf",
          "sed -i 's/^FRESHCLAM_DELAY=disabled-warn.*$//g' /etc/sysconfig/freshclam",

          # Daily full file system scan
          "echo '0 0 * * * root #{SCAN_COMMAND}' > /etc/cron.d/clamscan",
          "service crond restart",

          "service sshd stop",

          # Attach OSSEC volume
          "volume_id=$(aws ec2 describe-volumes --region ap-northeast-1 --filters Name=tag-key,Values=ossec-manager-volume Name=tag:barcelona,Values=#{district.name} | jq -r '.Volumes[0].VolumeId')",
          'instance_id=$(curl -H "X-aws-ec2-metadata-token: $IMDSTOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)',
          "aws ec2 attach-volume --region ap-northeast-1 --volume-id $volume_id --instance-id $instance_id --device /dev/xvdh",

          # Register its private IP to Route53
          'private_ip=$(curl -H "X-aws-ec2-metadata-token: $IMDSTOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4)',
          "change_batch=$(echo '#{change_batch}' | sed -e \"s/{private_ip}/$private_ip/\")",
          "aws route53 change-resource-record-sets --hosted-zone-id #{district.private_hosted_zone_id} --change-batch $change_batch",

          # Wait for the volume and route53 record to be ready
          "sleep 60",

          # Initialize the volume if not initialized
          "[[ $(file -s /dev/xvdh) =~ :\\ data$ ]] && mkfs -t ext4 /dev/xvdh",
          "mkdir /ossec_mnt",
          "mount /dev/xvdh /ossec_mnt",
          "mkdir -p /ossec_mnt/ossec_data",
          "mkdir -p /ossec_mnt/elasticsearch",

          # Start/Install docker and compose
          "service docker start",
          "usermod -a -G docker ec2-user",
          "curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose",
          "chmod +x /usr/local/bin/docker-compose",

          # Setup OSSEC manager
          "sysctl -w vm.max_map_count=262144",
          "cd /wazuh && /usr/local/bin/docker-compose up -d"
        ].flatten

        # CloudWatch Logs configurations
        # See http://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html
        log_group_name = "Barcelona/#{district.name}/ossec-manager"
        user_data.add_file("/etc/awslogs/awslogs.conf", "root:root", "644", <<~EOS)
          [general]
          state_file = /var/lib/awslogs/agent-state

          [/var/log/dmesg]
          file = /var/log/dmesg
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/dmesg

          [/var/log/messages]
          file = /var/log/messages
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/messages
          datetime_format = %b %d %H:%M:%S

          [/var/log/secure]
          file = /var/log/secure
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/secure
          datetime_format = %b %d %H:%M:%S

          [/ossec_mnt/ossec_data/logs/alerts/alerts.log]
          file = /ossec_mnt/ossec_data/logs/alerts/alerts.log
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/ossec/data/logs/alerts.log
        EOS

        user_data.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)

        # Based on https://github.com/wazuh/wazuh-docker
        user_data.add_file("/wazuh/docker-compose.yml", "root:root", "644", <<~EOS)
          version: '2'
          services:
            wazuh:
              image: quay.io/degica/barcelona-wazuh
              restart: always
              ports:
                - "1514:1514/udp"
                - "1515:1515"
                - "514:514/udp"
              depends_on:
                - logstash
              links:
                - logstash
              volumes:
                - /ossec_mnt/ossec_data:/var/ossec/data
              environment:
                SLACK_URL: #{options[:slack_url]}
            logstash:
              image: wazuh/wazuh-logstash:2.0.1_5.5.1
              restart: always
              command: -f /etc/logstash/conf.d/
              links:
               - elasticsearch
              depends_on:
                - elasticsearch
              environment:
                - LS_HEAP_SIZE=2048m
            elasticsearch:
              image: elasticsearch:5.5.1
              restart: always
              command: elasticsearch -E node.name="node-1" -E cluster.name="wazuh" -E network.host=0.0.0.0
              environment:
                ES_JAVA_OPTS: "-Xms1g -Xmx1g"
              ulimits:
                nofile:
                  soft: 65536
                  hard: 65536
              volumes:
                - /ossec_mnt/elasticsearch:/usr/share/elasticsearch/data
            kibana:
              image: wazuh/wazuh-kibana:2.0.1_5.5.1
              restart: always
              ports:
                - "5601:5601"
              depends_on:
                - elasticsearch
              links:
                - wazuh
                - elasticsearch:elasticsearch
              entrypoint: sh wait-for-it.sh elasticsearch
        EOS

        user_data
      end

      def build_resources
        add_resource("AWS::EC2::Volume", "OSSECManagerVolume") do |j|
          j.AvailabilityZone ossec_volume_az
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
          # Bastion AMI is a plain Amazon Linux AMI. we just reuse it for OSSEC manager
          j.ImageId Barcelona::Network::BastionBuilder::AMI_IDS["ap-northeast-1"]
          j.InstanceType "t3.medium"
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
          j.ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
          j.Policies [
            {
              "PolicyName" => "ossec-manager-policy",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "ec2:DescribeVolumes",
                      "ec2:AttachVolume",
                      "route53:ChangeResourceRecordSets"
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

        add_resource("AWS::AutoScaling::AutoScalingGroup", "OSSECManagerASG", depends_on: ["OSSECManagerVolume"]) do |j|
          j.DesiredCapacity 1
          j.HealthCheckGracePeriod 0
          j.MaxSize 1
          j.MinSize 1
          j.HealthCheckType "EC2"
          j.LaunchConfigurationName ref("OSSECManagerLaunchConfiguration")
          # AZ of OSSEC manager and its EBS volume must match
          j.VPCZoneIdentifier [district.stack_resources["SubnetTrusted1"]]
          j.Tags [
            {
              "Key" => "Name",
              "Value" => join("-", cf_stack_name, "ossec-manager"),
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
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "SourceSecurityGroupId" => district.stack_resources["SecurityGroupBastion"]
            },
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
              "CidrIp" => district.cidr_block
            },
            # OSSEC authd
            {
              "IpProtocol" => "tcp",
              "FromPort" => 1515,
              "ToPort" => 1515,
              "CidrIp" => district.cidr_block
            },
            # Kibana
            {
              "IpProtocol" => "tcp",
              "FromPort" => 5601,
              "ToPort" => 5601,
              "SourceSecurityGroupId" => district.instance_security_group
            },
          ]
          j.SecurityGroupEgress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 80,
              "ToPort" => 80,
              "CidrIp" => '0.0.0.0/0'
            },
            {
              "IpProtocol" => "tcp",
              "FromPort" => 443,
              "ToPort" => 443,
              "CidrIp" => '0.0.0.0/0'
            },
            {
              "IpProtocol" => "icmp",
              "FromPort" => -1,
              "ToPort" => -1,
              "CidrIp" => '0.0.0.0/0'
            }
          ]
          j.Tags [
            tag("barcelona", district.name),
            tag("barcelona-role", "pcidss")
          ]
        end
      end

      def ossec_volume_az
        district.subnets("Private").find { |s|
          s.subnet_id == district.stack_resources["SubnetTrusted1"]
        }.availability_zone
      end
    end

    class PcidssStack < CloudFormation::Stack
      attr_accessor :district

      def initialize(district, plugin)
        stack_name = "#{district.name}-pcidss-plugin"
        @district = district
        super(stack_name, slack_url: plugin.plugin_attributes["slack_url"])
      end

      def build
        super do |builder|
          builder.add_builder PcidssBuilder.new(self, options)
        end
      end
    end

    class PcidssPlugin < Base
      # Exclude different file systems such as /proc and /dev (-xdev)
      # Files that have changed within a day (-mtime -1)
      SCAN_COMMAND = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

      def run_commands
        @run_commands ||= [
          "amazon-linux-extras install -y epel",
          "yum install -y clamav clamav-update tmpwatch fail2ban",

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

          # Ignores error on OSSEC installation process.
          "set +e",
          "yum install -y wazuh-agent-2.0.1",
          "sed -i 's/<server-ip>.*<\\/server-ip>/<server-hostname>ossec-manager.#{district.name}.bcn<\\/server-hostname>/g' /var/ossec/etc/ossec.conf",
          "/var/ossec/bin/agent-auth -m ossec-manager.#{district.name}.bcn",
          "/var/ossec/bin/ossec-control restart",
          "set -e",
        ].flatten
      end

      def on_container_instance_user_data(_instance, user_data)
        user_data.run_commands += run_commands

        user_data.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<EOS)
[wazuh_repo]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh
baseurl=https://packages.wazuh.com/yum/el/7/x86_64
protect=1
EOS
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        user_data.run_commands += run_commands
        user_data.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<EOS)
[wazuh_repo]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh
baseurl=https://packages.wazuh.com/yum/el/7/x86_64
protect=1
EOS
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      def on_created(_, _)
        stack_executor.create_or_update
      end

      def on_updated(_, _)
        stack_executor.create_or_update
      end

      def on_destroyed(_, _)
        stack_executor.delete
      end

      private

      def stack_executor
        stack = PcidssStack.new(district, self.model)
        CloudFormation::Executor.new(stack, district)
      end
    end
  end
end
