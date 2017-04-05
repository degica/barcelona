class ApplyDistrict
  attr_accessor :district
  delegate :aws, :s3_bucket_name, to: :district

  def initialize(district)
    @district = district
  end

  def create!(access_key_id, secret_access_key)
    # Set access_key_id and secret_access_key temporarily to pass validation
    # These will be erased in set_district_aws_credentials if Barcelona is
    # running as a ECS service
    district.aws_access_key_id = access_key_id
    district.aws_secret_access_key = secret_access_key
    if district.valid?
      set_district_aws_credentials(access_key_id, secret_access_key)

      create_s3_bucket
      generate_ssh_ca_key_pair
      create_ecs_cluster
    end
    district.save!
    update_ecs_config
    district.stack_executor.create
  end

  def update!(access_key_id = nil, secret_access_key = nil)
    if district.valid?
      set_district_aws_credentials(access_key_id, secret_access_key)
    end
    district.save!
  end

  def apply
    district.save!
    update_ecs_config
    district.stack_executor.update
  end

  def destroy!
    district.destroy!
  end

  def generate_ssh_ca_key_pair
    key_pair = OpenSSL::PKey::RSA.new 4096
    aws.s3.put_object(bucket: s3_bucket_name,
                      key: "#{district.name}/ssh_ca_key",
                      body: key_pair.to_pem,
                      server_side_encryption: "aws:kms")
    district.ssh_ca_public_key = key_pair.public_key.to_pem
  end

  def set_district_aws_credentials(access_key_id, secret_access_key)
    return if access_key_id.nil? || secret_access_key.nil?

    if running_as_ecs_task?
      district.aws_role = create_district_role(access_key_id, secret_access_key)
      district.aws_access_key_id = nil
      district.aws_secret_access_key = nil
    else
      district.aws_access_key_id = access_key_id
      district.aws_secret_access_key = secret_access_key
    end
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

  def create_district_role(access_key_id, secret_access_key)
    task_role_arn = ecs_task_credentials&.dig("RoleArn")
    raise RuntimeError.new("Role ARN doesn't exist") if task_role_arn.nil?

    iam = new_iam_client(access_key_id, secret_access_key)

    # This identity solves an issue where there are multiple barcelonas
    # and each barcelona has the same district name (e.g. default)
    barcelona_identity = Digest::SHA256.hexdigest(task_role_arn).first(8)
    district_role_name = "barcelona.#{district.name}.api-#{barcelona_identity}"

    create_district_role_if_not_exist(iam, district_role_name, task_role_arn)
  end

  def running_as_ecs_task?
    ecs_task_credentials.present?
  end

  def ecs_task_credentials
    @ecs_task_credentials ||= begin
                                relative_uri = ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI']
                                if relative_uri.present?
                                  uri = URI("http://169.254.170.2#{relative_uri}")
                                  res = Net::HTTP.get_response(uri)
                                  status_code = res.code.to_i
                                  if 200 <= status_code && status_code <= 299
                                    JSON.load(res.body)
                                  else
                                    raise RuntimeError
                                  end
                                else
                                  nil
                                end
                              end
  end

  def new_iam_client(access_key_id, secret_access_key)
    credentials = {
      region: district.region,
      credentials: Aws::Credentials.new(access_key_id, secret_access_key)
    }
    Aws::IAM::Client.new(credentials)
  end

  def create_district_role_if_not_exist(iam, district_role_name, task_role_arn)
    begin
      resp = iam.get_role(role_name: district_role_name)
    rescue Aws::IAM::Errors::NoSuchEntity => e
      Rails.logger.info e.message

      resp = iam.create_role(
        role_name: district_role_name,
        assume_role_policy_document: {
          "Version" => "2012-10-17",
          "Statement" => {
            "Effect" => "Allow",
            "Principal" => {"AWS": task_role_arn},
            "Action" => "sts:AssumeRole"
          }
        }.to_json
      )

      iam.put_role_policy(
        policy_name: "#{district_role_name}-policy",
        role_name: district_role_name,
        policy_document: {
          "Version" => "2012-10-17",
          "Statement" => {
            "Effect" => "Allow",
            # TODO: List up all required actions instead of *
            "Action" => [
              "ec2:*",
              "elasticloadbalancing:*",
              "iam:*",
              "ecs:*",
              "cloudformation:*",
              "lambda:*",
              "waf:*",
              "cloudwatch:*",
              "events:*",
              "logs:*",
              "route53:*",
              "s3:*",
              "sns:*",
              "ssm:*",
              "application-autoscaling:*",
              "autoscaling:*"
            ],
            "Resource" => ["*"]
          }
        }.to_json
      )

      # Sleeping in the middle of a request is really, really bad manner but because calling AssumeRole
      # right after creating a district role doesn't work, we need to wait several seconds.
      # Those AWS resource manipulation can be pushed to DelayedJob but for the following reasons
      # I think sleep is better
      # 1) Barcelona is not performance intensive thus it is acceptable that one worker process becomes
      #    non-responsible for seconds
      # 2) If CF execution is run by DelayedJob, "create district" API have to return "SUCCESS" response
      #    to the caller but the delayed job may fail for whatever reason. The caller should be told
      #    such kind of unexpected error immediately.
      #    Returning error immediately is far more important than making Barcelona high performance.
      # 3) I want to ensure that given access key can be removed when "create district" API responded.
      sts = Aws::STS::Client.new(region: district.region)
      10.times do |i|
        begin
          sts.assume_role(
            role_arn: resp.role.arn,
            role_session_name: "assume-role-check-#{SecureRandom.hex(4)}",
            duration_seconds: 900,
          )
        rescue Aws::STS::Errors::AccessDenied => e
          Rails.logger.info "Failed to assume role. Will retry in 1 second"
          sleep 1
        else
          # Calling AssumeRole twice in a very short interval seems to fail sometimes.
          sleep 1
          break
        end
      end
    end

    resp.role.arn
  end
end
