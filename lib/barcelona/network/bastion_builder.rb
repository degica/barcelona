module Barcelona
  module Network
    class BastionBuilder < CloudFormation::Builder
      # https://aws.amazon.com/amazon-linux-ami/
      # Amazon Linux AMI 2016.09.0
      AMI_IDS = {
        "us-east-1" => "ami-c58c1dd3",
        "us-east-2" => "ami-4191b524",
        "us-west-1" => "ami-7a85a01a",
        "us-west-2" => "ami-4836a428",
        "eu-west-1" => "ami-01ccc867",
        "eu-west-2" => "ami-b6daced2",
        "eu-central-1" => "ami-b968bad6",
        "ap-northeast-1" => "ami-923d12f5",
        "ap-northeast-2" => "ami-9d15c7f3",
        "ap-southeast-1" => "ami-fc5ae39f",
        "ap-southeast-2" => "ami-162c2575",
        "ap-south-1" => "ami-52c7b43d",
        "ca-central-1" => "ami-0bd66a6f",
        "sa-east-1" => "ami-37cfad5b"
      }

      def build_resources
        add_resource("AWS::AutoScaling::LaunchConfiguration", "BastionLaunchConfiguration") do |j|
          j.ImageId AMI_IDS[district.region]
          j.InstanceType "t2.nano"
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
        ud.packages += ["aws-cli", "yum-cron-security"]
        ud.add_user("hopper")
        ud.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)
        ud.run_commands += [
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
