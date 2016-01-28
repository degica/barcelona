class SystemTask
  attr_accessor :district
  delegate :aws, to: :district

  def initialize(district)
    @district = district
  end

  def run(container_instance_arns, env = {})
    return if container_instance_arns.empty?

    aws.ecs.register_task_definition(task_definition)

    aws.ecs.start_task(
      cluster: district.name,
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
