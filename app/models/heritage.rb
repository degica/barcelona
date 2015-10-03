class Heritage < ActiveRecord::Base
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  belongs_to :district

  attr_accessor :sync

  serialize :before_deploy

  validates :name, presence: true, uniqueness: true
  validates :district, presence: true

  accepts_nested_attributes_for :services
  accepts_nested_attributes_for :env_vars

  after_save :update_services

  def to_param
    name
  end

  def describe_services
    ecs.describe_services(
      cluster: district.name,
      services: services.map(&:service_name)
    ).services
  end

  def image_path
    return nil if container_name.blank?
    "#{container_name}:#{container_tag}"
  end

  def update_services
    return if image_path.nil?
    if sync
      DeployRunnerJob.perform_now self, sync: true
    else
      DeployRunnerJob.perform_later self
    end
  end

  private

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end
end
