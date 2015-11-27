class PortMapping < ActiveRecord::Base
  RANDOM_HOST_PORT_RANGE = (10000..19999)
  belongs_to :service, inverse_of: :port_mappings

  validates :service, :lb_port, :container_port, presence: true
  validates :host_port, numericality: {greater_than: 1023, less_than: 20000}
  validates :protocol, inclusion: { in: %w(tcp udp http https) }
  validate :validate_host_port_uniqueness_on_district, on: :create
  validate :validate_lb_port_and_protocol

  after_initialize do |mapping|
    mapping.protocol ||= "tcp"
  end

  before_validation :assign_host_port
  before_validation :assign_lb_port

  scope :lb_registerable, -> { where.not(protocol: "udp") }
  scope :tcp, -> { where(protocol: "tcp") }
  scope :udp, -> { where(protocol: "udp") }
  scope :http, -> { where(protocol: "http") }

  def to_task_definition
    {
      container_port: container_port,
      host_port: (http? || https?) ? nil : host_port,
      protocol: host_protocol
    }.compact
  end

  def http?
    protocol == 'http'
  end

  def https?
    protocol == 'https'
  end

  private

  def host_protocol
    (http? || https?) ? "tcp" : protocol
  end

  def assign_host_port
    return if host_port.present?
    available_ports = RANDOM_HOST_PORT_RANGE.to_a - used_host_ports
    self.host_port = available_ports.sample
  end

  def assign_lb_port
    return if lb_port.present?
    self.lb_port = 80 if http?
    self.lb_port = 443 if https?
  end

  def validate_host_port_uniqueness_on_district
    if used_host_ports.include? host_port
      errors.add(:host_port, "must be unique in a district")
    end
  end

  def validate_lb_port_and_protocol
    if (http? && lb_port != 80) || (https? && lb_port != 443)
      errors.add(:lb_port, "cannot be changed for http/https protocol")
    end
  end

  def used_host_ports
    @used_host_ports = PortMapping
                       .joins(service: { heritage: :district })
                       .where("heritages.district_id" => service.heritage.district.id)
                       .pluck(:host_port)
                       .compact
  end
end
