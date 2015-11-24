class UpdateUserTask < SystemTask
  attr_accessor :user

  def initialize(section, user)
    super(section)
    @user = user
  end

  def run
    Rails.logger.info "Updating user #{user.name} for #{section.cluster_name}"
    env = {
      "USER_NAME" => user.name,
      "USER_GROUPS" => user.instance_groups.join(","),
      "USER_PUBLIC_KEY" => user.public_key.presence,
      "USER_DOCKERCFG" => section.dockercfg.try(:to_json)
    }.compact

    arns = section.container_instances.map{ |c| c[:container_instance_arn] }
    super(arns, env)
  end

  def task_family
    "update_user"
  end

  def container_definition
    super.merge(
      image: "k2nr/docker-user-manager",
      mount_points: [
        {
          source_volume: "etc",
          container_path: "/etc"
        },
        {
          source_volume: "home",
          container_path: "/home"
        }
      ]
    )
  end

  def volumes
    [
      {
        name: "etc",
        host: {
          source_path: "/etc"
        }
      },
      {
        name: "home",
        host: {
          source_path: "/home"
        }
      }
    ]
  end
end
