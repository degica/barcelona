module Barcelona
  module Network
    class AutoscalingBuilder < CloudFormation::Builder
      # http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
      # amzn-ami-2018.03.c-amazon-ecs-optimized
      ECS_OPTIMIZED_AMI_IDS = {
        "us-east-1"      => "ami-644a431b",
        "us-east-2"      => "ami-79d8e21c",
        "us-west-1"      => "ami-4351bc20",
        "us-west-2"      => "ami-f189d189",
        "eu-west-1"      => "ami-39d530d4",
        "eu-west-2"      => "ami-2e9866c5",
        "eu-west-3"      => "ami-e976c694",
        "eu-central-1"   => "ami-9fe2e074",
        "ap-northeast-1" => "ami-7d0c7a90",
        "ap-northeast-2" => "ami-8f44f3e1",
        "ap-southeast-1" => "ami-ae1b5a44",
        "ap-southeast-2" => "ami-706cca12",
        "ca-central-1"   => "ami-c1b63ba5",
        "ap-south-1"     => "ami-f4b88a9b",
        "sa-east-1"      => "ami-a2c6e7ce",
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

        add_resource("AWS::SNS::Topic", "ASGSNSTopic") do |j|
          j.Subscription [
            {
              "Endpoint" => get_attr("ASGDrainingFunction", "Arn"),
              "Protocol" => "lambda"
            }
          ]
        end

        add_resource("AWS::IAM::Role", "ASGDrainingFunctionRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2012-10-17"
            j.Statement [
              {
                "Effect" => "Allow",
                "Principal" => {
                  "Service" => ["lambda.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          end
          j.Path "/"
          j.Policies [
            {
              "PolicyName" => "barcelona-#{stack.district.name}-asg-draining-function-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "autoscaling:CompleteLifecycleAction",
                      "ecs:ListContainerInstances",
                      "ecs:DescribeContainerInstances",
                      "ecs:UpdateContainerInstancesState",
                      "ecs:ListTasks",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:PutLogEvents",
                      "sns:Publish"
                    ],
                    "Resource" => ["*"]
                  }
                ]
              }
            }
          ]
        end

        add_resource("AWS::Lambda::Function", "ASGDrainingFunction") do |j|
          j.Code do |j|
            j.ZipFile File.read(Rails.root.join("drain_instance.py"))
          end

          j.Handler "index.lambda_handler"
          j.Runtime "python2.7"
          j.Timeout "15"
          j.Role get_attr("ASGDrainingFunctionRole", "Arn")
          j.Environment do |j|
            j.Variables do |j|
              j.CLUSTER_NAME stack.district.name
            end
          end
        end

        add_resource("AWS::Lambda::Permission", "ASGDrainingFunctionPermission") do |j|
          j.FunctionName ref("ASGDrainingFunction")
          j.Action "lambda:InvokeFunction"
          j.Principal "sns.amazonaws.com"
          j.SourceArn ref("ASGSNSTopic")
        end

        add_resource("AWS::IAM::Role", "LifecycleHookRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2012-10-17"
            j.Statement [
              {
                "Effect" => "Allow",
                "Principal" => {
                  "Service" => ["autoscaling.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          end
          j.ManagedPolicyArns [
            "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
          ]
        end

        add_resource("AWS::AutoScaling::LifecycleHook", "TerminatingLifecycleHook") do |j|
          j.AutoScalingGroupName ref("ContainerInstanceAutoScalingGroup")
          j.LifecycleTransition "autoscaling:EC2_INSTANCE_TERMINATING"
          j.NotificationTargetARN ref("ASGSNSTopic")
          j.RoleARN get_attr("LifecycleHookRole", "Arn")
        end
      end

      def instance_user_data
        user_data = options[:container_instance].user_data
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
