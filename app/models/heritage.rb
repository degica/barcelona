class Heritage < ActiveRecord::Base
  class Builder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::Logs::LogGroup", "LogGroup") do |j|
        j.LogGroupName heritage.log_group_name
        j.RetentionInDays 30
      end

    end

    def heritage
      options[:heritage]
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
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :releases, -> { order 'version DESC' }, dependent: :destroy, inverse_of: :heritage
  belongs_to :district, inverse_of: :heritages

  validates :name,
            presence: true,
            uniqueness: true,
            immutable: true,
            format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\z/ }
  validates :district, presence: true

  before_validation do |heritage|
    heritage.regenerate_token if heritage.token.blank?
  end

  accepts_nested_attributes_for :services, allow_destroy: true
  accepts_nested_attributes_for :env_vars

  after_initialize do |heritage|
    heritage.version ||= 1
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
      base[:environment] += env_vars.where(secret: false).map { |e| {name: e.key, value: e.value} }
    end

    district.hook_plugins(:heritage_task_definition, self, base)
  end

  def log_group_name
    "Barcelona/#{district.name}/#{name}"
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

  def cf_executor
    @cf_executor ||= begin
                       stack = Stack.new(self)
                       CloudFormation::Executor.new(stack, district.aws.cloudformation)
                     end
  end

  def apply_stack
    cf_executor.create_or_update
  end

  def delete_stack
    cf_executor.delete
  end
end
