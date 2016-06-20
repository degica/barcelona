class Oneoff < ActiveRecord::Base
  belongs_to :app
  validates :app, presence: true
  validates :command, presence: true

  attr_accessor :env_vars, :image_tag

  delegate :district, to: :app
  delegate :aws, to: :district

  after_initialize do |oneoff|
    oneoff.env_vars ||= []
  end

  def run(sync: false)
    aws.ecs.register_task_definition(
      family: task_family,
      container_definitions: [task_definition]
    )
    resp = aws.ecs.run_task(
      cluster: district.name,
      task_definition: task_family,
      overrides: {
        container_overrides: [
          {
            name: container_name,
            command: LaunchCommand.new(command).to_command,
            environment: env_vars.map { |k, v| {name: k, value: v} }
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
    !(%w(STOPPED MISSING).include?(status))
  end

  def run!(sync: false)
    run(sync: sync)
    save!
  end

  def status
    task&.containers&.first&.last_status
  end

  def exit_code
    task&.containers&.first&.exit_code
  end

  def reason
    task&.containers&.first&.reason
  end

  private

  def task
    return @task if @task.present?
    fetch_task
  end

  def fetch_task
    @task = aws.ecs.describe_tasks(
      cluster: district.name,
      tasks: [task_arn]
    ).tasks[0]
  end

  def task_family
    "#{app.name}-oneoff"
  end

  def container_name
    "#{app.name}-oneoff"
  end

  def image_path
    if image_tag.present?
      "#{app.image_name}:#{image_tag}"
    else
      app.image_path
    end
  end

  def task_definition
    app.base_task_definition(container_name).merge(
      cpu: 128,
      memory: 512,
      image: image_path
    )
  end
end
