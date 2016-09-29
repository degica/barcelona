module Barcelona
  module Network
    class BastionServer < CloudFormation::Resource
      def self.type
        "AWS::EC2::Instance"
      end

      def define_resource(json)
        super do |j|
          j.InstanceType "t2.micro"
          j.SourceDestCheck false
          j.ImageId "ami-29160d47"
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
