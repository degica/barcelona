class Service < ActiveRecord::Base
  include AwsAccessible

  belongs_to :heritage
  has_many :port_mappings, dependent: :destroy

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
  delegate :status, to: :backend

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

  private

  def backend
    @backend ||= Backend::Ecs::Adapter.new(self)
  end
end
