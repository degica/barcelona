class ApplyDistrict
  attr_accessor :district
  delegate :aws, :s3_bucket_name, to: :district

  def initialize(district)
    @district = district
  end

  def create!
    if district.valid?
      create_s3_bucket
      generate_ssh_ca_key_pair
      create_ecs_cluster
    end
    apply
  end

  def apply
    district.save!
    update_ecs_config
    create_or_update_network_stack
  end

  def destroy!
    district.destroy!
    delete_ecs_cluster
  end

  def generate_ssh_ca_key_pair
    key_pair = OpenSSL::PKey::RSA.new 4096
    aws.s3.put_object(bucket: s3_bucket_name,
                      key: "#{district.name}/ssh_ca_key",
                      body: key_pair.to_pem,
                      server_side_encryption: "aws:kms")
    district.ssh_ca_public_key = key_pair.public_key.to_pem
  end

  private

  def create_s3_bucket
    aws.s3.create_bucket(bucket: s3_bucket_name)
  rescue => e
    Rails.logger.error e
  end

  def update_ecs_config
    aws.s3.put_object(bucket: s3_bucket_name,
                      key: "#{district.name}/ecs.config",
                      body: ecs_config,
                      server_side_encryption: "aws:kms")
  end

  def ecs_config
    config = {
      "ECS_CLUSTER" => district.name,
      "ECS_AVAILABLE_LOGGING_DRIVERS" => '["awslogs", "json-file", "syslog", "fluentd"]',
      "ECS_RESERVED_MEMORY" => 128,
      "ECS_CONTAINER_STOP_TIMEOUT" => "5m",
      "ECS_ENABLE_TASK_IAM_ROLE" => "true",
      "ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST" => "true"
    }

    if district.dockercfg.present?
      config["ECS_ENGINE_AUTH_TYPE"] = "dockercfg"
      config["ECS_ENGINE_AUTH_DATA"] = district.dockercfg.to_json
    end
    config = district.hook_plugins(:ecs_config, self, config)
    config.map {|k, v| "#{k}=#{v}"}.join("\n")
  end

  def create_ecs_cluster
    aws.ecs.create_cluster(cluster_name: district.name)
  end

  def create_or_update_network_stack
    district.stack_executor.create_or_update
  end

  def delete_ecs_cluster
    aws.ecs.delete_cluster(cluster: district.name)
  end
end
