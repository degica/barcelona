class Oneoff < ActiveRecord::Base
  belongs_to :heritage
  validates :heritage, presence: true
  validates :command, presence: true

  attr_accessor :env_vars

  serialize :command

  after_initialize do |oneoff|
    oneoff.env_vars ||= []
  end

  def run(sync: false)
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
    if sync
      300.times do
        break unless running?
        sleep 3
      end
    end
  end

  def running?
    fetch_task
    !(["STOPPED", "MISSING"].include?(status))
  end

  def run!(sync: false)
    run(sync: sync)
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
    fetch_task
  end

  def fetch_task
    @task = ecs.describe_tasks(
      cluster: heritage.district.name,
      tasks: [task_arn]
    ).tasks[0]
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
      image: heritage.image_path,
      environment: heritage.env_vars.map { |e| {name: e.key, value: e.value} }
    }.compact
  end

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end
end
