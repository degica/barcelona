module Barcelona
  module Network
    class AutoscalingBuilder < CloudFormation::Builder
      # http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
      # amzn2-ami-ecs-hvm-2.0
      ECS_OPTIMIZED_AMI_IDS = {
        "us-east-1"      => "ami-0f81924348bcd01a1",
        "us-east-2"      => "ami-025e529ec693faba6",
        "us-west-1"      => "ami-0c4f775d282076047",
        "us-west-2"      => "ami-01262e56d9a240227",
        "eu-west-1"      => "ami-04c29bb1e9988c803",
        "eu-west-2"      => "ami-037af9c254c6dc46c",
        "eu-west-3"      => "ami-00c2374f0b16417ab",
        "eu-central-1"      => "ami-02171c9c6dfc9dd1a",
        "ap-northeast-1"      => "ami-0633805928291a0db",
        "ap-northeast-2"      => "ami-0bd857d087df070e6",
        "ap-southeast-1"      => "ami-0dfacf29e68ba0347",
        "ap-southeast-2"      => "ami-02a1d998121cea625",
        "ca-central-1"      => "ami-06a21d76fa509c0e8",
        "ap-south-1"      => "ami-005136f1190a5c6b7",
        "sa-east-1"      => "ami-0c16a6e54a2f933f0",
      }

      def ebs_optimized_by_default?
        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html
        !!(instance_type =~ /\A(a1|c4|c5.?|d2|f1|g3.?|h1|i3|m4|m5.?|p2|p3(dn)?|r4|r5.?|t3|u-.*|x1.?|z1d)\..*\z/)
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
            # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/al2ami-storage-config.html
            {
              "DeviceName" => "/dev/xvda",
              "Ebs" => {
                "DeleteOnTermination" => true,
                "VolumeSize" => 100,
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
          j.Runtime "python3.7"
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
