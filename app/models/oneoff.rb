class Oneoff < ActiveRecord::Base
  belongs_to :heritage
  validates :heritage, presence: true
  validates :command, presence: true

  attr_accessor :env_vars, :image_tag

  delegate :district, to: :heritage
  delegate :aws, to: :district

  after_initialize do |oneoff|
    oneoff.env_vars ||= []
  end

  def run(sync: false)
    definition = HeritageTaskDefinition.oneoff_definition(self)
    aws.ecs.register_task_definition(definition.to_task_definition)
    resp = aws.ecs.run_task(
      cluster: district.name,
      task_definition: definition.family_name,
      overrides: {
        container_overrides: [
          {
            name: definition.family_name,
            command: run_command,
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

  def run_command
    LaunchCommand.new(heritage, command).to_command
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
end
