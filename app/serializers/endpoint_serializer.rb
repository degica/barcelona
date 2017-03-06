class EndpointSerializer < ActiveModel::Serializer
  attributes :name, :public, :certificate_id, :dns_name
  belongs_to :district
end
