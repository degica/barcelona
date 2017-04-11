class EndpointSerializer < ActiveModel::Serializer
  attributes :name, :public, :certificate_id, :dns_name, :ssl_policy
  belongs_to :district
end
