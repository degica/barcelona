class UpdateUserTask
  include AwsAccessible
  attr_accessor :district, :user

  def initialize(district, user)
    @district = district
    @user = user
  end

  def run
    Rails.logger.info "Updating user #{user.name} for district #{district.name}"
    ecs.register_task_definition(
      family: "update_user",
      container_definitions: [
        {
          name: "update_user",
          cpu: 32,
          memory: 32,
          essential: true,
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
        }
      ],
      volumes: [
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
    )

    env = {
      "USER_NAME" => user.name,
      "USER_GROUPS" => user_groups.join(",")
    }
    env["USER_PUBLIC_KEY"] = user.public_key if user.public_key.present?
    env["USER_DOCKERCFG"] = district.dockercfg.to_json if district.dockercfg.present?

    resp = ecs.start_task(
      cluster: district.name,
      task_definition: "update_user",
      overrides: {
        container_overrides: [
          {
            name: "update_user",
            environment: env.map { |k, v| {name: k, value: v} }
          }
        ]
      },
      container_instances: district.container_instances.map{ |c| c[:container_instance_arn] }
    )
  end

  private

  def user_groups
    groups = []
    groups << "docker" if user.developer?
    groups << "wheel" if user.admin?
    groups
  end
end
