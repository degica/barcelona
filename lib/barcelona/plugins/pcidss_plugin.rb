# PCIDSS plugin
### This plugin adds the following resources/configuration to a district
### - Adds designated NTP server and configure container instances so that their refers the private NTP server
### - Installs Clam AV in all instances. Scans run every day.
### - Installs fail2ban in all instances
###
### Currently this plugin works only in Tokyo (ap-notheast-1) region

module Barcelona
  module Plugins
    class PcidssBuilder < CloudFormation::Builder
      delegate :district, to: :stack

      def ntp_server_user_data
        user_data = InstanceUserData.new
        user_data.packages += ["aws-cli", "awslogs", "jq"]

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

          "service stop sshd"
        ]

        # CloudWatch Logs configurations
        # See http://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html
        log_group_name = "Barcelona/#{district.name}/ntp_server"
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

          [/var/log/ecs/audit.log]
          file = /var/log/ecs/audit.log.*
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/ecs/audit.log
          datetime_format = %Y-%m-%dT%H:%M:%SZ

          [/var/log/ntpstats/ntpd.log]
          file = /var/log/ntpstats/ntpd.log
          log_group_name = #{log_group_name}
          log_stream_name = {ec2_id}/var/log/ntpstats/ntpd.log
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
          j.ImageId "ami-56d4ad31"
          j.InstanceType "t2.nano"
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
            }
          ]
          j.Tags [
            tag("barcelona", district.name),
            tag("barcelona-role", "pcidss")
          ]
        end
      end
    end

    class PcidssStack < CloudFormation::Stack
      attr_accessor :district

      def initialize(district)
        stack_name = "#{district.name}-pcidss-plugin"
        @district = district
        super(stack_name)
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
          "service ntpd restart"
        ].flatten
      end

      def on_container_instance_user_data(_instance, user_data)
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += run_commands

        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_server = template["BastionServer"]
        return template if bastion_server.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_server["Properties"]["UserData"])
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += run_commands
        bastion_server["Properties"]["UserData"] = user_data.build
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
        stack = PcidssStack.new(district)
        CloudFormation::Executor.new(stack, district.aws.cloudformation)
      end
    end
  end
end
