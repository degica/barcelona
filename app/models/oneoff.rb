class Oneoff < ActiveRecord::Base
  belongs_to :heritage
  validates :heritage, presence: true
  attr_accessor :env_vars, :image_tag

  delegate :district, to: :heritage
  delegate :aws, to: :district

  after_initialize do |oneoff|
    oneoff.env_vars ||= []
  end

  def run(sync: false, interactive: false)
    raise ArgumentError if sync && interactive

    definition = HeritageTaskDefinition.oneoff_definition(self)
    aws.ecs.register_task_definition(definition.to_task_definition)
    resp = aws.ecs.run_task(
      cluster: district.name,
      task_definition: definition.family_name,
      overrides: {
        container_overrides: [
          {
            name: definition.family_name,
            command: interactive ? watch_session_command : run_command,
          }
        ]
      }
    )
    @task = resp.tasks[0]
    self.task_arn = @task.task_arn
    if sync
      300.times do
        break if stopped?
        sleep 3
      end
    end
  end

  def run_command
    LaunchCommand.new(heritage, command).to_command
  end

  def interactive_run_command
    real_command = run_command.map { |c| '"' + c + '"' }.join(' ')
    [
      "docker exec -it",
      "$(docker ps -q -f label=com.amazonaws.ecs.task-arn=#{task_arn} -f label=com.amazonaws.ecs.container-name=#{container_name})",
      real_command
    ].join(' ')
  end

  def watch_session_command
    ["/barcelona/barcelona-run", "watch-interactive-session"]
  end

  def stopped?
    fetch_task
    %w(STOPPED MISSING).include?(status)
  end

  def run!(sync: false, interactive: false)
    run(sync: sync, interactive: interactive)
    save!
  end

  def container_instance_arn
    task&.container_instance_arn
  end

  def app_container
    task&.containers&.find { |c| c.name == "#{heritage.name}-oneoff" }
  end

  def container_name
    app_container&.name
  end

  def status
    task&.last_status
  end

  def exit_code
    app_container&.exit_code
  end

  def reason
    app_container&.reason
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
