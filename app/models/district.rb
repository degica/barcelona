class District < ActiveRecord::Base
  include EncryptAttribute

  before_save :update_ecs_config
  before_create :create_ecs_cluster
  after_destroy :delete_ecs_cluster

  has_many :heritages, inverse_of: :district, dependent: :destroy
  has_many :users_districts, dependent: :destroy
  has_many :users, through: :users_districts
  has_many :elastic_ips, dependent: :destroy
  has_many :plugins, dependent: :destroy, inverse_of: :district

  attr_accessor :sections

  validates :name, presence: true, uniqueness: true, immutable: true
  validates :s3_bucket_name, presence: true
  validates :vpc_id, presence: true
  validates :private_hosted_zone_id, presence: true

  # Allows nil when test environment
  # This is because encrypting/decrypting value is very slow
  # So to speed up specs we allow empty access keys
  validates :aws_access_key_id, presence: true, if: -> { !Rails.env.test? }
  validates :aws_secret_access_key, presence: true, if: -> { !Rails.env.test? }

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

  private

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
end
