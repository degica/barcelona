class District < ActiveRecord::Base
  include EncryptAttribute

  before_validation :set_default_attributes
  before_create :assign_default_users

  has_many :heritages, inverse_of: :district, dependent: :destroy
  has_many :users_districts, dependent: :destroy
  has_many :users, through: :users_districts
  has_many :plugins, dependent: :delete_all, inverse_of: :district

  validates :name, presence: true, uniqueness: true, immutable: true
  validates :region, :s3_bucket_name, :stack_name, :cidr_block, presence: true, immutable: true
  validates :nat_type, inclusion: {in: %w(instance managed_gateway managed_gateway_multi_az)}, allow_nil: true
  validates :cluster_backend, inclusion: {in: %w(autoscaling)}
  validates :cluster_size, numericality: {greater_than_or_equal_to: 0}

  # Allows nil when test environment
  # This is because encrypting/decrypting value is very slow
  # So to speed up specs we allow empty access keys
  validates :aws_access_key_id, presence: true, if: -> { !Rails.env.test? }
  validates :aws_secret_access_key, presence: true, if: -> { !Rails.env.test? }

  ECS_REGIONS = Aws.
                partition("aws").
                regions.select { |r| r.services.include?("ECS") }.
                map(&:name)
  validates :region, inclusion: {in: ECS_REGIONS}

  validate :validate_cidr_block

  serialize :dockercfg, JSON

  encrypted_attribute :aws_secret_access_key, secret_key: ENV['ENCRYPTION_KEY']

  accepts_nested_attributes_for :plugins

  def aws
    # these fallback "empty" value is a trick to speed up specs
    @aws ||= AwsAccessor.new(aws_access_key_id || "empty", aws_secret_access_key || "empty", region)
  end

  def to_param
    name
  end

  def vpc_id
    @vpc_id ||= stack_resources["VPC"]
  end

  def public_elb_security_group
    @public_elb_security_group ||= stack_resources["PublicELBSecurityGroup"]
  end

  def private_elb_security_group
    @private_elb_security_group ||= stack_resources["PrivateELBSecurityGroup"]
  end

  def instance_security_group
    @instance_security_group ||= stack_resources["InstanceSecurityGroup"]
  end

  def private_hosted_zone_id
    @private_hosted_zone_id ||= stack_resources["LocalHostedZone"]
  end

  def ecs_service_role
    @ecs_service_role ||= stack_resources["ECSServiceRole"]
  end

  def ecs_instance_profile
    @ecs_instance_profile ||= stack_resources["ECSInstanceProfile"]
  end

  def stack_resources
    @stack_resources ||= stack_executor.resource_ids
  end

  def bastion_ip
    bastion_server_id = stack_resources["BastionServer"]
    return nil if bastion_server_id.blank?

    resp = aws.ec2.describe_instances(instance_ids: [bastion_server_id])
    resp.reservations[0].instances[0].public_ip_address if resp.reservations.present?
  end

  def subnets(network = "Private")
    @subnets ||= aws.ec2.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [network]}
      ]
    ).subnets
  end

  def container_instances
    arns = aws.ecs.list_container_instances(cluster: name).container_instance_arns
    return [] if arns.blank?
    container_instances = aws.ecs.
                          describe_container_instances(cluster: name, container_instances: arns).
                          container_instances
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
        private_ip_address: ins.private_ip_address,
        launch_time: ins.launch_time,
        instance_type: ins.instance_type
      )
    end

    instances.map { |ec2_id, ins| ins.merge(ec2_instance_id: ec2_id) }
  end

  def update_instance_user_account(user)
    UpdateUserTask.new(self, user).run
  end

  def hook_plugins(trigger, origin, arg = nil)
    plugins.reverse.reduce(arg) do |a, plugin|
      plugin.hook(trigger, origin, a)
    end
  end

  def base_task_definition
    base = {
      environment: []
    }
    hook_plugins(:district_task_definition, self, base)
  end

  def delete_network_stack
    stack_executor.delete
  end

  def stack_status
    stack_executor.stack_status
  end

  def users_body
    users.map{|u| "#{u.name},#{u.public_key}"}.join("\n")
  end

  def set_default_attributes
    self.region ||= "us-east-1"
    self.s3_bucket_name ||= "barcelona-#{name}-#{Time.now.to_i}"
    self.cidr_block     ||= "10.#{Random.rand(256)}.0.0/16"
    self.stack_name     ||= "barcelona-#{name}"
    self.nat_type       ||= "instance"
    self.cluster_backend  ||= 'autoscaling'
    self.cluster_size     ||= 1
    self.cluster_instance_type ||= "t2.micro"
  end

  def network_stack
    Barcelona::Network::NetworkStack.new(self)
  end

  def stack_executor
    CloudFormation::Executor.new(network_stack, aws.cloudformation)
  end

  private

  def validate_cidr_block
    if IPAddr.new(cidr_block).to_range.count < 65536
      errors.add(:cidr_block, "subnet mask bits must be smaller than or equal to 16")
    end
  rescue IPAddr::InvalidAddressError
    errors.add(:cidr_block, "is not a valid IPv4 format")
  end

  def assign_default_users
    self.users = User.all
  end
end
