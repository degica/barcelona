# PCIDSS plugin
### This plugin adds the following resources/configuration to a district
### - Adds designated NTP server and configure container instances so that their refers the private NTP server
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
        user_data.packages += ["docker", "jq", "awslogs", "clamav", "clamav-update", "tmpwatch", "fail2ban", "yum-cron-security"]

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
          "service yum-cron start",

          # Install AWS Inspector agent
          "curl https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install | bash",

          # awslogs
          "ec2_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
          'sed -i -e "s/{ec2_id}/$ec2_id/g" /etc/awslogs/awslogs.conf',
          'sed -i -e "s/us-east-1/'+district.region+'/g" /etc/awslogs/awscli.conf',
          "service awslogs start",

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

          # NTP
          "sed -i '/^server /s/^/#/' /etc/ntp.conf",
          "sed -i 's/^logconfig .*/logconfig =all/' /etc/ntp.conf",
          'echo logfile /var/log/ntpstats/ntpd.log >> /etc/ntp.conf',
          district.subnets("Public").map(&:subnet_id).map { |id|
            "echo server #{id}.ntp.#{district.name}.bcn iburst >> /etc/ntp.conf"
          },
          "service ntpd restart",

          # Configure sshd
          'printf "\nTrustedUserCAKeys /etc/ssh/ssh_ca_key.pub\n" >> /etc/ssh/sshd_config',
          'sed -i -e "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config',
          "service sshd restart",

          # Attach OSSEC volume
          "volume_id=$(aws ec2 describe-volumes --region ap-northeast-1 --filters Name=tag-key,Values=ossec-manager-volume Name=tag:barcelona,Values=#{district.name} | jq -r '.Volumes[0].VolumeId')",
          "instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
          "aws ec2 attach-volume --region ap-northeast-1 --volume-id $volume_id --instance-id $instance_id --device /dev/xvdh",

          # Register its private IP to Route53
          "private_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)",
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
          "curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose",
          "chmod +x /usr/local/bin/docker-compose",

          # Setup OSSEC manager
          "sysctl -w vm.max_map_count=262144",
          "cd /tmp && /usr/local/bin/docker-compose up -d"
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
        user_data.add_file("/tmp/docker-compose.yml", "root:root", "644", <<~EOS)
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

      def ntp_server_user_data
        user_data = InstanceUserData.new
        user_data.packages += ["aws-cli", "awslogs", "jq", "yum-cron-security"]

        find_eni_command = [
          "aws ec2 --region=#{district.region} describe-network-interfaces",
          "--filters",
          "Name=status,Values=available",
          "Name=availability-zone,Values=$az",
          "Name=tag:barcelona,Values=#{district.name}",
          "Name=tag:barcelona-role,Values=pcidss"
        ].join(" ")
        user_data.run_commands += [
          "set -ex",
          "service yum-cron start",

          # Install AWS Inspector agent
          "curl https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install | bash",

          # awslogs
          "ec2_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
          'sed -i -e "s/{ec2_id}/$ec2_id/g" /etc/awslogs/awslogs.conf',
          'sed -i -e "s/us-east-1/'+district.region+'/g" /etc/awslogs/awscli.conf',
          "service awslogs start",

          "az=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)",
          # Find ENI for NTP which is in the same AZ
          "eni_id=$(#{find_eni_command} | jq -r '.NetworkInterfaces[0].NetworkInterfaceId')",
          # Attach it to myself
          "aws ec2 --region=#{district.region} attach-network-interface --network-interface-id $eni_id --instance-id $ec2_id --device-index 1",
          # Wait for the ENI to be ready
          "sleep 30",

          "sed -i 's/^logconfig .*/logconfig =all/' /etc/ntp.conf",
          'echo logfile /var/log/ntpstats/ntpd.log >> /etc/ntp.conf',
          # Listen on the ENI
          "echo interface listen eth1 >> /etc/ntp.conf",
          "service ntpd restart",

          "service sshd stop",

          # OSSEC agent
          "yum install -y wazuh-agent",
          "sed -i 's/<server-ip>.*<\\/server-ip>/<server-hostname>ossec-manager.#{district.name}.bcn<\\/server-hostname>/g' /var/ossec/etc/ossec.conf",
          "/var/ossec/bin/agent-auth -m ossec-manager.#{district.name}.bcn",
          "/var/ossec/bin/ossec-control restart",
        ]

        # CloudWatch Logs configurations
        # See http://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html
        log_group_name = "Barcelona/#{district.name}/ntp-server"
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

          [/var/log/ntpstats/ntpd.log]
          file = /var/log/ntpstats/ntpd.log
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/ntpstats/ntpd.log
        EOS

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

      def build_resources
        subnet_ids = district.subnets("Public").map(&:subnet_id)
        subnet_ids.each_with_index do |subnet_id|
          postfix = subnet_id.gsub("-", "")
          add_resource("AWS::EC2::NetworkInterface", "ENI#{postfix}") do |j|
            j.SubnetId subnet_id
            j.GroupSet [ref("NTPServerSG")]
            j.Tags [
              tag("barcelona", district.name),
              tag("barcelona-role", "pcidss")
            ]
          end

          add_resource("AWS::Route53::RecordSet", "RecordSet#{postfix}") do |j|
            j.HostedZoneId district.private_hosted_zone_id
            j.Name [subnet_id, "ntp", district.name, "bcn"].join(".")
            j.TTL 300
            j.Type "A"
            j.ResourceRecords [get_attr("ENI#{postfix}", "PrimaryPrivateIpAddress")]
          end
        end

        add_resource("AWS::AutoScaling::LaunchConfiguration",
                     "NTPServerLaunchConfiguration") do |j|
          j.IamInstanceProfile ref("NTPServerProfile")
          j.ImageId "ami-4af5022c"
          j.InstanceType "t2.micro"
          j.AssociatePublicIpAddress true
          j.SecurityGroups [ref("NTPServerSG")]
          j.UserData ntp_server_user_data.build
        end

        add_resource("AWS::IAM::Role", "NTPServerRole") do |j|
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
              "PolicyName" => "ntp-server-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "ec2:DescribeNetworkInterfaces",
                      "ec2:AttachNetworkInterface",
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

        add_resource("AWS::IAM::InstanceProfile", "NTPServerProfile") do |j|
          j.Path "/"
          j.Roles [ref("NTPServerRole")]
        end

        add_resource("AWS::AutoScaling::AutoScalingGroup", "NTPServerASG") do |j|
          j.DesiredCapacity 1
          j.MaxSize 1
          j.MinSize 1
          j.HealthCheckGracePeriod 0
          j.HealthCheckType "EC2"
          j.LaunchConfigurationName ref("NTPServerLaunchConfiguration")
          j.VPCZoneIdentifier [district.stack_resources["SubnetDmz1"], district.stack_resources["SubnetDmz2"]]
          j.Tags [
            {
              "Key" => "Name",
              "Value" => "barcelona-#{district.name}-ntp-server",
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

        add_resource("AWS::EC2::SecurityGroup", "NTPServerSG") do |j|
          j.GroupDescription "SG for OSSEC Manager Instance"
          j.VpcId district.vpc_id
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "icmp",
              "FromPort" => -1,
              "ToPort" => -1,
              "CidrIp" => district.cidr_block
            },
            {
              "IpProtocol" => "udp",
              "FromPort" => 123,
              "ToPort" => 123,
              "CidrIp" => district.cidr_block
            },
          ]
          j.SecurityGroupEgress [
            {
              "IpProtocol" => "udp",
              "FromPort" => 123,
              "ToPort" => 123,
              "CidrIp" => '0.0.0.0/0'
            },
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
            },
            # OSSEC agent
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
          ]
          j.Tags [
            tag("barcelona", district.name),
            tag("barcelona-role", "pcidss")
          ]
        end

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
          j.ImageId "ami-4af5022c"
          j.InstanceType "t2.medium"
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
              "PolicyName" => "ossec-manager-policy",
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
              "IpProtocol" => "udp",
              "FromPort" => 123,
              "ToPort" => 123,
              "CidrIp" => '0.0.0.0/0'
            },
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
      SYSTEM_PACKAGES = ["clamav", "clamav-update", "tmpwatch", "fail2ban"]
      # Exclude different file systems such as /proc and /dev (-xdev)
      # Files that have changed within a day (-mtime -1)
      SCAN_COMMAND = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

      def run_commands
        @run_commands ||= [
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

          # NTP
          "sed -i '/^server /s/^/#/' /etc/ntp.conf",
          "sed -i 's/^logconfig .*/logconfig =all/' /etc/ntp.conf",
          'echo logfile /var/log/ntpstats/ntpd.log >> /etc/ntp.conf',
          district.subnets("Public").map(&:subnet_id).map { |id|
            "echo server #{id}.ntp.#{district.name}.bcn iburst >> /etc/ntp.conf"
          },
          "service ntpd restart",

          # Ignores error on OSSEC installation process.
          "set +e",
          "yum install -y wazuh-agent",
          "sed -i 's/<server-ip>.*<\\/server-ip>/<server-hostname>ossec-manager.#{district.name}.bcn<\\/server-hostname>/g' /var/ossec/etc/ossec.conf",
          "/var/ossec/bin/agent-auth -m ossec-manager.#{district.name}.bcn",
          "/var/ossec/bin/ossec-control restart",
          "set -e",
        ].flatten
      end

      def on_container_instance_user_data(_instance, user_data)
        user_data.packages += SYSTEM_PACKAGES
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
        user_data.packages += SYSTEM_PACKAGES
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
        CloudFormation::Executor.new(stack, district.aws.cloudformation)
      end
    end
  end
end
