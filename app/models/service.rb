class Service < ActiveRecord::Base
  belongs_to :heritage, inverse_of: :services
  has_many :port_mappings, inverse_of: :service, dependent: :destroy

  validates :name, presence: true
  validates :cpu, numericality: {greater_than: 0}
  validates :memory, numericality: {greater_than: 0}

  accepts_nested_attributes_for :port_mappings

  after_initialize do |service|
    service.cpu ||= 512
    service.memory ||= 512
  end

  after_destroy :delete_service

  delegate :district, to: :heritage
  delegate :status, :desired_count, :running_count, :pending_count, to: :backend

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

  private

  def backend
    @backend ||= Backend::Ecs::Adapter.new(self)
  end
end
