class PortMapping < ActiveRecord::Base
  HOST_PORT_RANGE = (10000..19999)
  belongs_to :service

  validates :host_port, uniqueness: true
  validates :host_port, :lb_port, :container_port, presence: true

  before_validation :assign_host_port

  private

  def assign_host_port
    available_ports = HOST_PORT_RANGE.to_a - self.class.pluck(:host_port)
    self.host_port = available_ports.sample
  end
end
