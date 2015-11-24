class TerminateInstanceTask < SystemTask
  def run(arns, env={})
    env = {
      "STOP_TIMEOUT" => 120,
      "AWS_REGION" => "ap-northeast-1"
    }
    super(arns, env)
  end

  def task_family
    "terminate-instance"
  end

  def container_definition
    super.merge(
      image: "k2nr/ecs-instance-terminator",
      mount_points: [
        {
          source_volume: "docker-socket",
          container_path: "/var/run/docker.sock"
        }
      ]
    )
  end

  def volumes
    [
      {
        name: "docker-socket",
        host: {
          source_path: "/var/run/docker.sock"
        }
      }
    ]
  end
end
