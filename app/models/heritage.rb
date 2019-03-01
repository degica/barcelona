class Heritage < ActiveRecord::Base
  class Builder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::Logs::LogGroup", "LogGroup") do |j|
        j.LogGroupName heritage.log_group_name
        j.RetentionInDays 365
      end

      if heritage.scheduled_tasks.present?
        definition = HeritageTaskDefinition.schedule_definition(heritage).
                       to_task_definition(without_task_role: true, camelize: true)
        add_resource("AWS::ECS::TaskDefinition", "ScheduleTaskDefinition", retain: true) do |j|
          j.ContainerDefinitions definition["ContainerDefinitions"]
          j.Family definition["Family"]
          j.TaskRoleArn ref("TaskRole")
          j.ExecutionRoleArn ref("TaskExecutionRole")
        end

        heritage.scheduled_tasks.each_with_index do |s, i|
          event_name =  "ScheduledEvent#{i}"
          command = s["command"]
          command = Shellwords.split(command) if s["command"].is_a?(String)
          run_command = LaunchCommand.new(heritage, command,
                                          shell_format: false).to_command
          add_resource("AWS::Events::Rule", event_name) do |j|
            j.Description "Scheduled Task Rule"
            j.State "ENABLED"
            j.ScheduleExpression s["schedule"]
            j.Targets [
              {
                "Arn" => get_attr("ScheduleHandler", "Arn"),
                "Id" => "barcelona-#{heritage.name}-schedule-event-#{i}",
                "Input" => {
                  cluster: heritage.district.name,
                  task_family: "#{heritage.name}-schedule",
                  command: run_command
                }.to_json
              }
            ]
          end

          add_resource("AWS::Lambda::Permission", "PermissionFor#{event_name}") do |j|
            j.FunctionName ref("ScheduleHandler")
            j.Action "lambda:InvokeFunction"
            j.Principal "events.amazonaws.com"
            j.SourceArn get_attr(event_name, "Arn")
          end
        end

        add_resource("AWS::Lambda::Function", "ScheduleHandler") do |j|
          j.Handler "index.handler"
          j.Role get_attr("ScheduleHandlerRole", "Arn")
          j.Runtime "nodejs6.10"
          j.Timeout 60
          j.Code do |j|
            j.ZipFile schedule_handler_code
          end
        end

        add_resource("AWS::IAM::Role", "ScheduleHandlerRole") do |j|
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
              "PolicyName" => "barcelona-schedule-handler-role-#{heritage.name}",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "ecs:RunTask",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:PutLogEvents",
                    ],
                    "Resource" => ["*"]
                  }
                ]
              }
            }
          ]
        end
      end

      add_resource("AWS::IAM::Role", "TaskExecutionRole") do |j|
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
        j.ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
        j.Policies [
          {
            "PolicyName" => "barcelona-ecs-task-execution-role-#{heritage.name}",
            "PolicyDocument" => {
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Effect" => "Allow",
                  "Action" => [
                    "ssm:GetParameters",
                    "secretsmanager:GetSecretValue",
                  ],
                  "Resource" => [
                    sub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/barcelona/#{heritage.district.name}/*"),
                    sub("arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:barcelona/#{heritage.district.name}/*"),
                  ]
                }
              ]
            }
          }
        ]
      end

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
            "PolicyName" => "barcelona-ecs-task-role-#{heritage.name}",
            "PolicyDocument" => {
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Effect" => "Allow",
                  "Action" => ["logs:CreateLogStream",
                               "logs:PutLogEvents"],
                  "Resource" => ["*"]
                },
                {
                  "Effect" => "Allow",
                  "Action" => ["s3:GetObject"],
                  "Resource" => [
                    "arn:aws:s3:::#{heritage.district.s3_bucket_name}/heritages/#{heritage.name}/*",
                    "arn:aws:s3:::#{heritage.district.s3_bucket_name}/certs/*",
                  ]
                }
              ]
            }
          }
        ]
      end
    end

    def heritage
      options[:heritage]
    end

    def schedule_handler_code
      File.read(Rails.root.join("schedule_handler.js"))
    end
  end

  class Stack < CloudFormation::Stack
    def initialize(heritage)
      stack_name = "heritage-#{heritage.name}"
      super(stack_name, heritage: heritage)
    end

    def build
      super do |builder|
        builder.add_builder Builder.new(self, options)
      end
    end
  end

  has_many :services, inverse_of: :heritage, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :environments
  has_many :oneoffs, dependent: :destroy
  has_many :releases, -> { order 'version DESC' }, dependent: :destroy, inverse_of: :heritage
  belongs_to :district, inverse_of: :heritages

  validates :name,
            presence: true,
            uniqueness: true,
            immutable: true,
            format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\z/ }
  validates :district, presence: true

  serialize :scheduled_tasks, JSON

  before_validation do |heritage|
    heritage.regenerate_token if heritage.token.blank?
  end

  accepts_nested_attributes_for :services, allow_destroy: true
  accepts_nested_attributes_for :env_vars
  accepts_nested_attributes_for :environments, allow_destroy: true

  after_initialize do |heritage|
    heritage.version ||= 2
    heritage.scheduled_tasks ||= []
  end
  after_save :apply_stack
  after_destroy :delete_stack

  def to_param
    name
  end

  def describe_services
    district.aws.ecs.describe_services(
      cluster: district.name,
      services: services.map(&:service_name)
    ).services
  end

  def image_path
    return nil if image_name.blank?
    tag = image_tag || 'latest'
    "#{image_name}:#{tag}"
  end

  def save_and_deploy!(without_before_deploy: false, description: "")
    save!
    release = releases.create!(description: description)
    update_services(release, without_before_deploy)
    release
  end

  def regenerate_token
    self.token = SecureRandom.uuid
  end

  def base_task_definition(task_name, with_environment: true)
    base = district.base_task_definition.merge(
      name: task_name,
      cpu: 256,
      memory: 256,
      essential: true,
      image: image_path,
      log_configuration: {
        log_driver: "awslogs",
        options: {
          "awslogs-group" => log_group_name,
          "awslogs-region" => district.region,
          "awslogs-stream-prefix" => name
        }
      }
    )
    if with_environment
      base[:environment] += environment_set
      base[:secrets] += environments.secrets.map { |e| {name: e.name, value_from: e.namespaced_value_from} }
    end

    district.hook_plugins(:heritage_task_definition, self, base)
  end

  def log_group_name
    "Barcelona/#{district.name}/#{name}"
  end

  def task_role_id
    cf_executor&.resource_ids["TaskRole"]
  end

  def task_execution_role_id
    cf_executor&.resource_ids["TaskExecutionRole"]
  end

  def cf_executor
    @cf_executor ||= begin
                       stack = Stack.new(self)
                       CloudFormation::Executor.new(stack, district.aws.cloudformation)
                     end
  end

  def environment_set
    legacy_env_vars = env_vars.where(secret: false).map { |e| [e.key, e.value] }.to_h
    envs = environments.plains.map { |e| [e.name, e.value] }.to_h
    union = legacy_env_vars.merge(envs)
    union.map { |k, v| {name: k, value: v} }
  end

  def legacy_secrets
    env_vars.where(secret: true).where.not(key: environments.secrets.pluck(:name))
  end

  private

  def update_services(release, without_before_deploy)
    return if image_path.nil?
    DeployRunnerJob.perform_later(
      self,
      without_before_deploy: without_before_deploy,
      description: release.description
    )
  end

  def apply_stack
    cf_executor.create_or_update
  end

  def delete_stack
    cf_executor.delete
  end
end
