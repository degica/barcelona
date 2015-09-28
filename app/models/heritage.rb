class Heritage < ActiveRecord::Base
  has_many :services, dependent: :destroy
  has_many :env_vars, dependent: :destroy
  has_many :oneoffs, dependent: :destroy
  belongs_to :district

  validates :name, presence: true, uniqueness: true
  validates :district, presence: true

  accepts_nested_attributes_for :services

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

  def container_image_path
    return nil if container_name.blank?
    path = "#{container_name}:#{container_tag}"
    url = district.docker_registry_url
    url.present? ? "#{url}/#{path}" : path
  end

  def update_services
    return if container_image_path.nil?
    services.each do |service|
      Rails.logger.info "Updating service #{service.name} ..."
      service.apply_to_ecs(container_image_path)
    end
  end

  private

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end
end
