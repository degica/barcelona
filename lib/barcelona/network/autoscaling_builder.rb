module Barcelona
  module Network
    class AutoscalingBuilder < CloudFormation::Builder
      # http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
      # amzn2-ami-ecs-hvm-2.0
      # You can see the latest version stored in public SSM parameter store
      # https://ap-northeast-1.console.aws.amazon.com/systems-manager/parameters/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id/description?region=ap-northeast-1
      # latest info is Version: 126, LastModifiedDate: 2023-11-09T05:06:38.507000+09:00, image_name: amzn2-ami-ecs-hvm-2.0.20231103-x86_64-ebs
      ECS_OPTIMIZED_AMI_IDS = {
        "us-east-1"      => "ami-0fac1e606981b292b",
        "us-east-2"      => "ami-063496725830a8a8e",
        "us-west-1"      => "ami-0000fe44649a08f57",
        "us-west-2"      => "ami-0469e9041ea25600d",
        "eu-west-1"      => "ami-02a28f8b317b61070",
        "eu-west-2"      => "ami-0b07faf56462d5ae8",
        "eu-west-3"      => "ami-031791ba176819256",
        "eu-central-1"      => "ami-06d198da422b4d577",
        "ap-northeast-1"      => "ami-07acd7f8d547a49e9",
        "ap-northeast-2"      => "ami-03bd90cb269e7a1df",
        "ap-southeast-1"      => "ami-030e545d619a1548a",
        "ap-southeast-2"      => "ami-00e6a4a4d0cb8ca0f",
        "ca-central-1"      => "ami-03df65cedd1751c66",
        "ap-south-1"      => "ami-044c72a801982b446",
        "sa-east-1"      => "ami-03b271468d5914879",
      }

      def ebs_optimized_by_default?
        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html
        !!(instance_type =~ /\A(a1|c4|c5.?|d2|f1|g3.?|h1|i3|m4|m5.?|m6.+|p2|p3(dn)?|r4|r5.?|t3|u-.*|x1.?|z1d)\..*\z/)
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
          j.MetadataOptions do |m|
            m.HttpTokens 'required'
          end
          j.BlockDeviceMappings [
            # Root volume
            # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/al2ami-storage-config.html
            {
              "DeviceName" => "/dev/xvda",
              "Ebs" => {
                "DeleteOnTermination" => true,
                "Encrypted" => true,
                "Iops" => 3000,
                "Throughput" => 125,
                "VolumeSize" => 100,
                "VolumeType" => "gp3"
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
                      "ecs:DescribeTasks",
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
          j.Runtime "python3.7"
          j.Timeout "60"
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
