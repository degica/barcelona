class District < ActiveRecord::Base
  include EncryptAttribute

  before_save :update_ecs_config
  before_create :create_ecs_cluster
  after_create :put_users_file
  after_destroy :delete_ecs_cluster

  has_many :heritages, dependent: :destroy
  has_many :users_districts, dependent: :destroy
  has_many :users, through: :users_districts
  has_many :elastic_ips, dependent: :destroy

  attr_accessor :sections

  validates :name, presence: true, uniqueness: true
  validates :s3_bucket_name, presence: true
  validates :vpc_id, presence: true
  validates :private_hosted_zone_id, presence: true
  validates :aws_access_key_id, presence: true
  validates :aws_secret_access_key, presence: true

  serialize :dockercfg, JSON

  encrypted_attribute :aws_access_key_id, secret_key: ENV['ENCRYPTION_KEY']
  encrypted_attribute :aws_secret_access_key, secret_key: ENV['ENCRYPTION_KEY']

  after_initialize do |district|
    district.sections = {
      public: DistrictSection.new(:public, self),
      private: DistrictSection.new(:private, self)
    }
  end

  def aws
    @aws ||= AwsAccessor.new(aws_access_key_id, aws_secret_access_key)
  end

  def to_param
    name
  end

  def subnets(section)
    sections[section.downcase.to_sym].subnets
  end

  def launch_instances(count: 1, instance_type:, section: :private)
    sections[section.to_sym].launch_instances(count: count, instance_type: instance_type)
  end

  def container_instances(section: :private)
    sections[section].container_instances
  end

  def update_instance_user_account(user)
    sections.each do |_, section|
      section.update_instance_user_account(user)
    end
  end

  def put_users_file
    aws.s3.put_object(bucket: s3_bucket_name,
                  key: "#{name}/users",
                  body: users_body,
                  server_side_encryption: "AES256")
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
