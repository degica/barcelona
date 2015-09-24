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
    self.task_arn = resp.tasks[0].task_arn
  end

  def run!
    run
    save!
  end

  private

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
