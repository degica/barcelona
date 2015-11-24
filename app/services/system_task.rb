class SystemTask
  attr_accessor :section, :user
  delegate :aws, :district, to: :section

  def initialize(section, user)
    @section = section
    @user = user
  end

  def run(container_instance_arns, env = {})
    td = task_definition
    aws.ecs.register_task_definition(task_definition)

    resp = aws.ecs.start_task(
      cluster: section.cluster_name,
      task_definition: task_family,
      overrides: {
        container_overrides: [
          {
            name: task_family,
            environment: env.map { |k, v| {name: k, value: v.to_s} }
          }
        ]
      },
      container_instances: container_instance_arns
    )
  end

  def task_definition
    {
      family: task_family,
      container_definitions: [container_definition],
      volumes: volumes
    }
  end

  def container_definition
    district.base_task_definition.merge(
      name: task_family,
      cpu: 32,
      memory: 32,
      essential: true
    )
  end

  def volumes
    []
  end

  def task_family
    raise NotImplementedError
  end
end
