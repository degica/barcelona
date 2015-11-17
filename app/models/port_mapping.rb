class PortMapping < ActiveRecord::Base
  HOST_PORT_RANGE = (10000..19999)
  belongs_to :service

  validates :host_port, uniqueness: true
  validates :host_port, :lb_port, :container_port, presence: true
  validates :protocol, inclusion: { in: %w(tcp udp) }

  after_initialize do |mapping|
    mapping.protocol ||= "tcp"
  end

  before_validation :assign_host_port

  scope :tcp, -> { where(protocol: "tcp") }
  scope :udp, -> { where(protocol: "udp") }

  private

  def assign_host_port
    available_ports = HOST_PORT_RANGE.to_a - self.class.pluck(:host_port)
    self.host_port = available_ports.sample
  end
end
