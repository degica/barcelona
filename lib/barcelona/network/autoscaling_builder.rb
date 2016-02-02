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
          "start ecs",
          "sleep 10",
          "ecs_cluster=$(curl http://localhost:51678/v1/metadata | jq -r .Cluster)",
          "while : ; do",
          "  pending_tasks_count=$(aws ecs describe-clusters --region=$AWS_REGION --clusters=$ecs_cluster | jq -r .clusters[0].pendingTasksCount)",
          "  [[ $pending_tasks_count -eq 0 ]] && break",
          "  sleep 3",
          "done",
          "/opt/aws/bin/cfn-signal -e $? --region $AWS_REGION --stack #{stack.name} --resource ContainerInstanceAutoScalingGroup || true"
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
