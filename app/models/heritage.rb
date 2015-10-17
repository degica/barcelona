class Heritage < ActiveRecord::Base
  include AwsAccessible
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  has_many :events, dependent: :destroy
  belongs_to :district

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
    tag = "latest" if image_tag.blank?
    "#{image_name}:#{tag}"
  end

  def update_services
    return if image_path.nil?
    DeployRunnerJob.perform_later self
  end
end
