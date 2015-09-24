class Oneoff < ActiveRecord::Base
  belongs_to :heritage
  validates :heritage, presence: true

  attr_accessor :command, :env_vars

  after_initialize do |oneoff|
    oneoff.env_vars ||= []
  end

  def run
    ecs.register_task_definition(
      family: task_family,
      container_definitions: [task_definition]
    )
    resp = ecs.run_task(
      cluster: heritage.district.name,
      task_definition: task_family,
      overrides: {
        container_overrides: [
          {
            name: heritage.name,
            command: command,
            environment: env_vars
          }
        ]
      }
    )
    @task = resp.tasks[0]
    self.task_arn = @task.task_arn
  end

  def run!
    run
    save!
  end

  def status
    task.try(:containers).try(:[], 0).try(:last_status)
  end

  def exit_code
    task.try(:containers).try(:[], 0).try(:exit_code)
  end

  private

  def task
    return @task if @task.present?
    resp = ecs.describe_tasks(
      cluster: heritage.district.name,
      tasks: [task_arn]
    )
    @task = resp.tasks[0]
  end

  def task_family
    "#{heritage.name}-oneoff"
  end

  def task_definition
    {
      name: heritage.name,
      cpu: 128,
      memory: 128,
      essential: true,
      image: heritage.container_image_path,
      environment: heritage.env_vars.map { |e| {name: e.key, value: e.value} }
    }.compact
  end

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end
end
