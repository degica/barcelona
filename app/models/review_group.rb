class ReviewGroup < ApplicationRecord
  class Builder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::IAM::Role", "TaskRole") do |j|
        j.AssumeRolePolicyDocument do |j|
          j.Version "2012-10-17"
          j.Statement [
            {
              "Effect" => "Allow",
              "Principal" => {
                "Service" => ["ecs-tasks.amazonaws.com"]
              },
              "Action" => ["sts:AssumeRole"]
            }
          ]
        end
        j.Path "/"
        j.Policies [
          {
            "PolicyName" => "barcelona-ecs-task-role-reviewgroup-#{group.name}",
            "PolicyDocument" => {
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Effect" => "Allow",
                  "Action" => ["logs:CreateLogStream",
                               "logs:PutLogEvents"],
                  "Resource" => ["*"]
                }
              ]
            }
          }
        ]
      end
    end

    def group
      options[:group]
    end
  end

  class Stack < CloudFormation::Stack
    def initialize(group)
      stack_name = "#{group.district.name}-reviewapp-group-#{group.name}"
      super(stack_name, group: group)
    end

    def build
      super do |builder|
        builder.add_builder Builder.new(self, options)
      end
    end
  end

  belongs_to :endpoint
  has_many :review_apps, dependent: :destroy

  validates :token, :base_domain, :name, presence: true
  validates :name, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :base_domain, format: { with: /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?)?\z/ }

  before_validation do
    regenerate_token if self.token.blank?
  end

  after_save :apply_stack
  after_destroy :delete_stack

  delegate :district, to: :endpoint

  def regenerate_token
    self.token = SecureRandom.uuid
  end

  def task_role_id
    stack_resources["TaskRole"]
  end

  def cf_executor
    @cf_executor ||= begin
                       stack = Stack.new(self)
                       CloudFormation::Executor.new(stack, district.aws.cloudformation)
                     end
  end

  private

  def apply_stack
    cf_executor.create_or_update
  end

  def delete_stack
    cf_executor.delete
  end

  def stack_resources
    @stack_resources ||= cf_executor.resource_ids
  end
end
