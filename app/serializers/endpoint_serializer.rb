class EndpointSerializer < ActiveModel::Serializer
  attributes :name, :public, :certificate_id
end
