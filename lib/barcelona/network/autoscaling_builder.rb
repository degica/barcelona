module Barcelona
  module Network
    class AutoscalingBuilder < CloudFormation::Builder
      def build_resources
        add_resource("AWS::AutoScaling::LaunchConfiguration",
                     "ContainerInstanceLaunchConfiguration") do |j|

          j.IamInstanceProfile ref("ECSInstanceProfile")
          j.ImageId "ami-e9724c87" # amzn-ami-2015.09.e-amazon-ecs-optimized
          j.InstanceType instance_type
          j.SecurityGroups [ref("InstanceSecurityGroup")]
          j.UserData instance_user_data
          j.BlockDeviceMappings [
            {
              "DeviceName" => "/dev/xvda",
              "Ebs" => {
                "DeleteOnTermination" => true,
                "VolumeSize" => 80,
                "VolumeType" => "gp2"
              }
            }
          ]
        end

        add_resource(AutoScalingGroup,
                     "ContainerInstanceAutoScalingGroup",
                     desired_capacity: desired_capacity)
      end

      def instance_user_data
        user_data = options[:container_instance].user_data
        user_data.run_commands += [
          "/opt/aws/bin/cfn-signal -e 0 --region ap-northeast-1 --stack #{stack.name} --resource ContainerInstanceAutoScalingGroup"
        ]
        user_data.build
      end

      def instance_type
        options[:instance_type]
      end

      def desired_capacity
        options[:desired_capacity]
      end
    end
  end
end
