module Barcelona
  module Network
    class BastionBuilder < CloudFormation::Builder
      # https://aws.amazon.com/amazon-linux-2/release-notes/
      # Amazon Linux 2 AMI
      # You can see the latest version stored in public SSM parameter store
      # https://ap-northeast-1.console.aws.amazon.com/systems-manager/parameters/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2/description?region=ap-northeast-1
      AMI_IDS = {
        "us-east-1"      => "ami-0fe472d8a85bc7b0e",
        "us-east-2"      => "ami-0ea1d45dcdd47edf6",
        "us-west-1"      => "ami-0fc161d91b03576d0",
        "us-west-2"      => "ami-0849a313b038afda0",
        "eu-west-1"      => "ami-08c149f9b2ace933d",
        "eu-west-2"      => "ami-02a1ade676420a021",
        "eu-west-3"      => "ami-065764f88497fd546",
        "eu-central-1"      => "ami-04a2b113b98bfa0e8",
        "ap-northeast-1"      => "ami-0b8b7786ce75a2b4f",
        "ap-northeast-2"      => "ami-0a1d2fce2d3ca6e35",
        "ap-southeast-1"      => "ami-02c7d3513f9fdf3f6",
        "ap-southeast-2"      => "ami-0043df2e553ad12b6",
        "ca-central-1"      => "ami-01aca21057a013fd0",
        "ap-south-1"      => "ami-093613b5938a7e47c",
        "sa-east-1"      => "ami-03faa3bc786326505",
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
          j.MetadataOptions do |m|
            m.HttpTokens 'required'
          end
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
          # imdsv2
          'IMDSTOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`',

          # awslogs
          'ec2_id=$(curl -H "X-aws-ec2-metadata-token: $IMDSTOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)',
          # There are cases when we must wait for meta-data
          'while [ "$ec2_id" = "" ]; do sleep 1 ; ec2_id=$(curl -H "X-aws-ec2-metadata-token: $IMDSTOKEN" -v http://169.254.169.254/latest/meta-data/instance-id) ; done',
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
