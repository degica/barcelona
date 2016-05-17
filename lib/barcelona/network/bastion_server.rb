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
          j.ImageId "ami-383c1956"
          j.KeyName options[:bastion_key_pair]
          j.UserData options[:user_data] if options[:user_data]
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
    end
  end
end
