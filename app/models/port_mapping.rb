class PortMapping < ActiveRecord::Base
  belongs_to :service

  validates :host_port, uniqueness: true
  validates :host_port, :lb_port, :container_port, presence: true

  before_validation :assign_host_port

  private

  def assign_host_port
    available_ports = (1024..65535).to_a - self.class.pluck(:host_port)
    self.host_port = available_ports.sample
  end
end
