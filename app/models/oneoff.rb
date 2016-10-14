class Oneoff < ActiveRecord::Base
  belongs_to :heritage
  validates :heritage, presence: true

  delegate :district, to: :heritage
  delegate :aws, to: :district

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
            # Ideally Barcelona should not override LANG but because all official docker images
            # doesn't set LANG as UTF8 we can't use multi byte characters in
            # the interactive session without this override
            environment: interactive ? [{name: "LANG", value: "C.UTF-8"}] : []
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
    LaunchCommand.new(heritage, command.split(" "), shell_format: false).to_command
  end

  def interactive_run_command
    real_command = run_command.join(' ')
    [
      "docker exec -it",
      "$(docker ps -q -f label=com.barcelona.oneoff-id=#{self.id})",
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
