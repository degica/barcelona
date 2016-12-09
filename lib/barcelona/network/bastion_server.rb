module Barcelona
  module Network
    class BastionServer < CloudFormation::Resource
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

      def self.type
        "AWS::EC2::Instance"
      end

      def define_resource(json)
        super do |j|
          j.InstanceType "t2.nano"
          j.SourceDestCheck false
          j.ImageId AMI_IDS[district.region]
          j.UserData user_data
          j.NetworkInterfaces [
            {
              "AssociatePublicIpAddress" => true,
              "DeviceIndex" => 0,
              "SubnetId" => ref("SubnetDmz1"),
              "GroupSet" => [ref("SecurityGroupBastion")]
            }
          ]
          j.Tags [
            tag("Name", join("-", cf_stack_name, "bastion"))
          ]
        end
      end

      def user_data
        ud = InstanceUserData.new
        ud.packages += ["aws-cli"]
        ud.add_user("hopper")
        ud.add_file("/etc/ssh/ssh_ca_key.pub", "root:root", "644", district.ssh_format_ca_public_key)
        ud.run_commands += [
          'printf "\nTrustedUserCAKeys /etc/ssh/ssh_ca_key.pub\n" >> /etc/ssh/sshd_config',
          "service sshd restart"
        ]
        ud.build
      end

      def district
        options[:district]
      end
    end
  end
end
