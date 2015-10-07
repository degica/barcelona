class Heritage < ActiveRecord::Base
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  belongs_to :district

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
    return nil if image_name.blank?
    "#{image_name}:#{image_tag}"
  end

  def update_services
    return if image_path.nil?
    DeployRunnerJob.perform_later self
  end

  private

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end
end
