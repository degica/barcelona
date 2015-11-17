class PortMapping < ActiveRecord::Base
  RANDOM_HOST_PORT_RANGE = (10000..19999)
  belongs_to :service

  validates :host_port, :lb_port, :container_port, presence: true
  validates :host_port, numericality: {greater_than: 1023, less_than: 20000}
  validates :protocol, inclusion: { in: %w(tcp udp) }
  validate :validate_host_port_uniqueness_on_district

  after_initialize do |mapping|
    mapping.protocol ||= "tcp"
  end

  before_validation :assign_host_port, on: :create

  scope :tcp, -> { where(protocol: "tcp") }
  scope :udp, -> { where(protocol: "udp") }

  private

  def assign_host_port
    available_ports = RANDOM_HOST_PORT_RANGE.to_a - used_host_ports
    self.host_port = available_ports.sample
  end

  def validate_host_port_uniqueness_on_district
    if used_host_ports.include? host_port
      errors.add(:host_port, "must be unique in a district")
    end
  end

  def used_host_ports
    @used_host_ports = PortMapping
                       .joins(service: { heritage: :district })
                       .where("heritages.district_id" => service.heritage.district.id)
                       .pluck(:host_port)
  end
end
