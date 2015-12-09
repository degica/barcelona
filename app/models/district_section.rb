class DistrictSection
  attr_accessor :name, :district

  delegate :aws,
           :vpc_id,
           :s3_bucket_name,
           :private_hosted_zone_id,
           :ecs_instance_role,
           :instance_security_group,
           :users,
           :dockercfg,
           to: :district

  def initialize(name, district)
    @name = name.to_s
    @district = district
  end

  def subnets
    @subnets ||= aws.ec2.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [name.camelize]}
      ]
    ).subnets
  end

  def launch_instances(count: 1, instance_type:, associate_eip: false)
    if associate_eip
      available_eips = district.elastic_ips.available(district).to_a
      raise "Elastic IP not available" if available_eips.count < count
    end

    count.times do |i|
      allocation_id = available_eips[i].allocation_id if associate_eip
      instance = ContainerInstance.new(self,
                                       instance_type: instance_type,
                                       eip_allocation_id: allocation_id)
      instance.launch
    end
  end

  def terminate_instance(container_instance_arn: nil)
    unless container_instance_arn
      arns = aws.ecs.list_container_instances(cluster: cluster_name).container_instance_arns
      return [] if arns.blank?
      container_instance_arn = aws.ecs
                               .describe_container_instances(cluster: cluster_name, container_instances: [arns.sample])
                               .container_instances[0]
                               .container_instance_arn
    end
    TerminateInstanceTask.new(self).run([container_instance_arn])
  end

  def container_instances
    arns = aws.ecs.list_container_instances(cluster: cluster_name).container_instance_arns
    return [] if arns.blank?
    container_instances = aws.ecs
                          .describe_container_instances(cluster: cluster_name, container_instances: arns)
                          .container_instances
    instances = {}
    container_instances.each do |ci|
      instance = {
        status: ci.status,
        container_instance_arn: ci.container_instance_arn,
        remaining_resources: ci.remaining_resources,
        registered_resources: ci.registered_resources,
        running_tasks_count: ci.running_tasks_count,
        pending_tasks_count: ci.pending_tasks_count
      }
      instances[ci.ec2_instance_id] = instance
    end

    ec2_instances = aws.ec2.describe_instances(
      instance_ids: container_instances.map(&:ec2_instance_id)
    ).reservations.map(&:instances).flatten

    ec2_instances.each do |ins|
      instances[ins.instance_id].merge!(
        private_ip_address: ins.private_ip_address
      )
    end

    instances.map { |ec2_id, ins| ins.merge(ec2_instance_id: ec2_id) }
  end

  def update_instance_user_account(user)
    UpdateUserTask.new(self, user).run
  end

  def cluster_name
    case name
    when "private"
      district.name
    when "public"
      "#{district.name}-public"
    end
  end

  def update_ecs_config
    aws.s3.put_object(bucket: s3_bucket_name,
                      key: "#{cluster_name}/ecs.config",
                      body: ecs_config,
                      server_side_encryption: "AES256")
  end

  def create_ecs_cluster
    aws.ecs.create_cluster(cluster_name: cluster_name)
  end

  def delete_ecs_cluster
    aws.ecs.delete_cluster(cluster: cluster_name)
  end

  def public?
    name == "public"
  end

  private

  def ecs_config
    config = {
      "ECS_CLUSTER" => cluster_name,
      "ECS_AVAILABLE_LOGGING_DRIVERS" => '["json-file", "syslog", "fluentd"]',
      "ECS_RESERVED_MEMORY" => 128
    }
    if dockercfg.present?
      config["ECS_ENGINE_AUTH_TYPE"] = "dockercfg"
      config["ECS_ENGINE_AUTH_DATA"] = dockercfg.to_json
    end
    config = district.hook_plugins(:ecs_config, self, config)
    config.map {|k, v| "#{k}=#{v}"}.join("\n")
  end

  def users_body
    users.map{|u| "#{u.name},#{u.public_key}"}.join("\n")
  end
end
