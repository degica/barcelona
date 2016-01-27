class District < ActiveRecord::Base
  include EncryptAttribute

  attr_writer :vpc_id, :public_elb_security_group, :private_elb_security_group,
              :instance_security_group, :private_hosted_zone_id,
              :ecs_instance_profile, :ecs_service_role

  before_validation :set_default_attributes
  before_create :assign_default_users
  after_create :create_s3_bucket
  after_create :create_ecs_cluster
  after_create :create_network_stack
  after_save :update_ecs_config
  after_destroy :delete_ecs_cluster

  has_many :heritages, inverse_of: :district, dependent: :destroy
  has_many :users_districts, dependent: :destroy
  has_many :users, through: :users_districts
  has_many :elastic_ips, dependent: :destroy
  has_many :plugins, dependent: :destroy, inverse_of: :district

  attr_accessor :sections

  validates :name, presence: true, uniqueness: true, immutable: true
  validates :s3_bucket_name, :stack_name, :cidr_block, presence: true
  validates :nat_type, inclusion: {in: %w(instance managed_gateway managed_gateway_multi_az)}, allow_nil: true

  # Allows nil when test environment
  # This is because encrypting/decrypting value is very slow
  # So to speed up specs we allow empty access keys
  validates :aws_access_key_id, presence: true, if: -> { !Rails.env.test? }
  validates :aws_secret_access_key, presence: true, if: -> { !Rails.env.test? }

  validate :validate_cidr_block

  serialize :dockercfg, JSON

  encrypted_attribute :aws_access_key_id, secret_key: ENV['ENCRYPTION_KEY']
  encrypted_attribute :aws_secret_access_key, secret_key: ENV['ENCRYPTION_KEY']

  accepts_nested_attributes_for :plugins

  after_initialize do |district|
    district.sections = {
      public: DistrictSection.new(:public, self),
      private: DistrictSection.new(:private, self)
    }
  end

  def aws
    # these fallback "empty" value is a trick to speed up specs
    @aws ||= AwsAccessor.new(aws_access_key_id || "empty", aws_secret_access_key || "empty")
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

  def subnets(section)
    sections[section.downcase.to_sym].subnets
  end

  def launch_instances(count: 1, instance_type:, associate_eip: false, section: :private)
    sections[section.to_sym].launch_instances(count: count,
                                              instance_type: instance_type,
                                              associate_eip: associate_eip)
  end

  def terminate_instance(section: :private, container_instance_arn: nil)
    sections[section.to_sym].terminate_instance(container_instance_arn: container_instance_arn)
  end

  def container_instances(section: :private)
    sections[section].container_instances
  end

  def update_instance_user_account(user)
    sections.each do |_, section|
      section.update_instance_user_account(user)
    end
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

  def create_network_stack
    stack_executor.create
  end

  def apply_network_stack
    stack_executor.create_or_update
  end

  def delete_network_stack
    stack_executor.delete
  end

  def stack_status
    stack_executor.stack_status
  end

  private

  def set_default_attributes
    self.s3_bucket_name ||= "barcelona-#{name}-#{Time.now.to_i}"
    self.cidr_block     ||= "10.#{Random.rand(256)}.0.0/16"
    self.stack_name     ||= "barcelona-#{name}"
  end

  def create_s3_bucket
    aws.s3.create_bucket(bucket: s3_bucket_name)
  rescue => e
    Rails.logger.error e
  end

  def update_ecs_config
    sections.each do |_, section|
      section.update_ecs_config
    end
  end

  def create_ecs_cluster
    sections.each do |_, section|
      section.create_ecs_cluster
    end
  end

  def users_body
    users.map{|u| "#{u.name},#{u.public_key}"}.join("\n")
  end

  def delete_ecs_cluster
    sections.each do |_, section|
      section.delete_ecs_cluster
    end
  end

  def network_stack
    Barcelona::Network::NetworkStack.new(
      stack_name,
      cidr_block: cidr_block,
      bastion_key_pair: bastion_key_pair,
      nat_type: nat_type
    )
  end

  def stack_executor
    CloudFormation::Executor.new(network_stack, aws.cloudformation)
  end

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
