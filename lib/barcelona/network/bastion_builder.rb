module Barcelona
  module Network
    class BastionBuilder < CloudFormation::Builder
      # https://aws.amazon.com/amazon-linux-ami/
      # Amazon Linux AMI 2016.09.0
      AMI_IDS = {
        "us-east-1" => "ami-c481fad3",
        "us-east-2" => "ami-71ca9114",
        "us-west-1" => "ami-de347abe",
        "us-west-2" => "ami-b04e92d0",
        "eu-west-1" => "ami-d41d58a7",
        "eu-central-1" => "ami-0044b96f",
        "ap-northeast-1" => "ami-1a15c77b",
        "ap-southeast-1" => "ami-7243e611",
        "ap-southeast-2" => "ami-55d4e436",
        "ca-central-1" => "ami-b48b39d0"
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
        ud.packages += ["aws-cli"]
        ud.add_user("hopper")
        ud.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)
        ud.run_commands += [
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
