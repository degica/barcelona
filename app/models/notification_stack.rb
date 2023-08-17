class NotificationStack < CloudFormation::Stack
  class Builder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::IAM::Role", "NotificationRole") do |j|
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
            "PolicyName" => "barcelona-#{stack.district.name}-slack-notification-role",
            "PolicyDocument" => {
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Effect" => "Allow",
                  "Action" => [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                  ],
                  "Resource" => ["*"]
                }
              ]
            }
          }
        ]
      end

      stack.district.notifications.each_with_index do |notification, i|
        case notification.target
        when "slack"
          subscription_name = "SlackSubscription#{i}"
          permission_name = "NotificationPermission#{i}"
          function_name = "SlackNotification#{i}"

          add_resource("AWS::SNS::Subscription", subscription_name) do |j|
            j.Endpoint get_attr(function_name, "Arn")
            j.Protocol "lambda"
            j.TopicArn topic_arn
          end

          add_resource("AWS::Lambda::Permission", permission_name) do |j|
            j.FunctionName ref(function_name)
            j.Action "lambda:InvokeFunction"
            j.Principal "sns.amazonaws.com"
          end

          add_resource("AWS::Lambda::Function", function_name) do |j|
            j.Handler "index.handler"
            j.Role get_attr("NotificationRole", "Arn")
            j.Environment do |j|
              j.Variables do |j|
                j.ENDPOINT notification.endpoint
                j.DISTRICT stack.district.name
              end
            end
            j.Runtime "nodejs18.x"
            j.Code do |j|
              j.ZipFile slack_notification_code
            end
          end
        end
      end
    end

    def topic_arn
      stack.district.notification_topic
    end

    def slack_notification_code
      File.read(Rails.root.join("slack_notification.js"))
    end
  end

  attr_accessor :district

  def initialize(district)
    @district = district
    stack_name = "barcelona-#{district.name}-notifications"
    super(stack_name)
  end

  def build
    super do |builder|
      builder.add_builder Builder.new(self, options)
    end
  end
end
