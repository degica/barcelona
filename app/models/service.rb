class Service < ActiveRecord::Base
  DEFAULT_REVERSE_PROXY = 'quay.io/degica/barcelona-reverse-proxy:latest'.freeze
  WEB_CONTAINER_PORT_DEFAULT = 3000

  belongs_to :heritage, inverse_of: :services
  has_many :listeners, inverse_of: :service, dependent: :destroy
  has_many :port_mappings, inverse_of: :service, dependent: :destroy

  serialize :hosts, JSON
  serialize :health_check, JSON

  validates :name,
            presence: true,
            uniqueness: {scope: :heritage_id},
            format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\z/ }
  validates :cpu, numericality: {greater_than: 0}, allow_nil: true
  validates :memory, numericality: {greater_than: 0}
  validates :service_type, inclusion: { in: %w[default web] }
  validates :name, :service_type, :public, immutable: true
  validates :command, presence: true
  validate :validate_health_check
  validate :validate_listener_count

  accepts_nested_attributes_for :port_mappings
  accepts_nested_attributes_for :listeners, allow_destroy: true

  after_initialize do |service|
    service.memory ||= 512
    service.reverse_proxy_image ||= DEFAULT_REVERSE_PROXY
    service.service_type ||= 'default'
    service.hosts ||= []
    service.health_check ||= {}
  end

  after_create :create_port_mappings
  after_save :update_port_mappings
  after_destroy :delete_service

  delegate :district, to: :heritage
  delegate :status, :running_count, :pending_count, to: :backend

  def desired_count
    desired_container_count || backend.desired_count
  end

  def apply
    backend.apply
  end

  def delete_service
    backend.delete
  end

  def service_name
    "#{heritage.name}-#{name}"
  end

  def endpoint
    backend.endpoint
  end

  def scale(count)
    backend.scale(count)
  end

  def web?
    service_type == "web"
  end

  def web_container_port
    super or WEB_CONTAINER_PORT_DEFAULT
  end

  def http_port_mapping
    nil unless web?
    port_mappings.find_by(protocol: 'http')
  end

  def https_port_mapping
    nil unless web?
    port_mappings.find_by(protocol: 'https')
  end

  def deployment_finished?(deployment_id)
    backend.deployment_finished?(deployment_id)
  end

  private

  def validate_listener_count
    # Currently ECS doesn't allow multiple target groups
    if listeners.count > 1
      errors.add(:listeners, "must be less than or equal to 1")
    end
  end

  def create_port_mappings
    return unless web?

    self.port_mappings.create!(container_port: web_container_port, protocol: 'http')
    self.port_mappings.create!(container_port: web_container_port, protocol: 'https')
  end

  def update_port_mappings
    return unless web?

    self.port_mappings.where(protocol: 'http').update_all(container_port: self.web_container_port)
    self.port_mappings.where(protocol: 'https').update_all(container_port: self.web_container_port)
  end

  def backend
    @backend ||= case heritage.version
                 when 1
                   Backend::Ecs::V1::Adapter.new(self)
                 when 2
                   Backend::Ecs::V2::Adapter.new(self)
                 else
                   raise NotImplementedError
                 end
  end

  def validate_health_check
    self.health_check = {} if health_check.nil?
    health_check["protocol"] ||= "tcp"
    errors.add(:protocol, "is not supported") if health_check["protocol"] != "tcp"
  end
end
