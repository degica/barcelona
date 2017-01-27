module Barcelona
  module Network
    class AutoscalingBuilder < CloudFormation::Builder
      # http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
      # amzn-ami-2016.09.d-amazon-ecs-optimized
      ECS_OPTIMIZED_AMI_IDS = {
        "us-east-1" => "ami-d69c74c0",
        "us-east-2" => "ami-64270201",
        "us-west-1" => "ami-bc90c2dc",
        "us-west-2" => "ami-8e7bc4ee",
        "eu-west-1" => "ami-48f9a52e",
        "eu-west-2" => "ami-62aea406",
        "eu-central-1" => "ami-6b428d04",
        "ap-northeast-1" => "ami-372f5450",
        "ap-southeast-1" => "ami-69208a0a",
        "ap-southeast-2" => "ami-307f7853",
        "ca-central-1" => "ami-b2e65bd6"
      }

      def ebs_optimized_by_default?
        !!(instance_type =~ /\A(c4|m4|d2)\..*\z/)
      end

      def build_resources
        add_resource("AWS::AutoScaling::LaunchConfiguration",
                     "ContainerInstanceLaunchConfiguration") do |j|

          j.IamInstanceProfile ref("ECSInstanceProfile")
          j.ImageId ECS_OPTIMIZED_AMI_IDS[stack.district.region]
          j.InstanceType instance_type
          j.SecurityGroups [ref("InstanceSecurityGroup")]
          j.UserData instance_user_data
          j.EbsOptimized ebs_optimized_by_default?
          j.BlockDeviceMappings [
            # Root volume
            {
              "DeviceName" => "/dev/xvda",
              "Ebs" => {
                "DeleteOnTermination" => true,
                "VolumeSize" => 20,
                "VolumeType" => "gp2"
              }
            },
            # devicemapper volume used by docker
            {
              "DeviceName" => "/dev/xvdcz",
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
                     desired_capacity: desired_capacity,
                     district_name: stack.district.name
                    )
      end

      def instance_user_data
        user_data = options[:container_instance].user_data
        user_data.run_commands += [
          "start ecs",
          "sleep 10", # Wait for ecs agent to be running
          "ecs_cluster=$(curl http://localhost:51678/v1/metadata | jq -r .Cluster)",
          # Wait for all tasks in the cluster to be running
          "while : ; do",
          "  pending_tasks_count=$(aws ecs describe-clusters --region=$AWS_REGION --clusters=$ecs_cluster | jq -r .clusters[0].pendingTasksCount)",
          "  [[ $pending_tasks_count -eq 0 ]] && break",
          "  sleep 3",
          "done",
          "sleep 30", # Wait for services to be attached to ELB
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
