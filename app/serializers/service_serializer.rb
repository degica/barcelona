class ServiceSerializer < ActiveModel::Serializer
  attributes :name, :public, :command, :cpu, :memory, :endpoint, :status, :port_mappings

  belongs_to :heritage
end
