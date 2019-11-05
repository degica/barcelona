module Barcelona
  module Network
    class BastionBuilder < CloudFormation::Builder
      # https://aws.amazon.com/amazon-linux-2/release-notes/
      # Amazon Linux 2 AMI
      AMI_IDS = {
        "us-east-1"      => "ami-00dc79254d0461090",
        "us-east-2"      => "ami-00bf61217e296b409",
        "us-west-1"      => "ami-024c80694b5b3e51a",
        "us-west-2"      => "ami-0a85857bfc5345c38",
        "eu-west-1"      => "ami-040ba9174949f6de4",
        "eu-west-2"      => "ami-00e8b55a2e841be44",
        "eu-west-3"      => "ami-05a51ff00c1d77571",
        "eu-central-1"      => "ami-0f3a43fbf2d3899f7",
        "ap-northeast-1"      => "ami-0064e711cbc7a825e",
        "ap-northeast-2"      => "ami-02b3330196502d247",
        "ap-southeast-1"      => "ami-00942d7cd4f3ca5c0",
        "ap-southeast-2"      => "ami-08a74056dfd30c986",
        "ca-central-1"      => "ami-007dbcbce3118978b",
        "ap-south-1"      => "ami-040c7ad0a93be494e",
        "sa-east-1"      => "ami-053f8b6627112b46e",
      }

      def build_resources
        add_resource("AWS::EC2::SecurityGroup", "SecurityGroupBastion") do |j|
          j.GroupDescription "Security Group for bastion servers"
          j.VpcId ref("VPC")
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "CidrIp" => "0.0.0.0/0"
            }
          ]
          j.SecurityGroupEgress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "CidrIp" => options[:cidr_block]
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
            # OSSEC agent
            {
              "IpProtocol" => "udp",
              "FromPort" => 1514,
              "ToPort" => 1514,
              "CidrIp" => options[:cidr_block]
            },
            # OSSEC authd
            {
              "IpProtocol" => "tcp",
              "FromPort" => 1515,
              "ToPort" => 1515,
              "CidrIp" => options[:cidr_block]
            },
          ]
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::IAM::InstanceProfile", "BastionProfile") do |j|
          j.Path "/"
          j.Roles [ref("BastionRole")]
        end

        add_resource("AWS::IAM::Role", "BastionRole") do |j|
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
        end

        add_resource("AWS::AutoScaling::LaunchConfiguration", "BastionLaunchConfiguration") do |j|
          j.IamInstanceProfile ref("BastionProfile")
          j.ImageId AMI_IDS[district.region]
          j.InstanceType "t3.micro"
          j.SecurityGroups [ref("SecurityGroupBastion")]
          j.AssociatePublicIpAddress true
          j.UserData user_data
        end

        add_resource(BastionAutoScaling, "BastionAutoScaling",
                     district_name: district.name,
                     depends_on: ["VPCGatewayAttachment"])
      end

      def user_data
        ud = InstanceUserData.new
        ud.packages += ["aws-cli", "awslogs", "yum-cron"]
        ud.add_user("hopper")
        ud.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)

        log_group_name = "Barcelona/#{district.name}/bastion"
        ud.add_file("/etc/awslogs/awslogs.conf", "root:root", "644", <<~EOS)
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
        EOS

        ud.run_commands += [
          # awslogs
          "ec2_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)",
          'sed -i -e "s/{ec2_id}/$ec2_id/g" /etc/awslogs/awslogs.conf',
          'sed -i -e "s/us-east-1/'+district.region+'/g" /etc/awslogs/awscli.conf',
          "systemctl start awslogsd",

          "service yum-cron start",
          'printf "\nTrustedUserCAKeys /etc/ssh/ssh_ca_key.pub\n" >> /etc/ssh/sshd_config',
          'sed -i -e "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config',
          "service sshd restart",

          # Install AWS Inspector agent
          "curl https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install | bash"
        ]
        ud.build
      end

      def district
        stack.district
      end
    end
  end
end
