class EndpointSerializer < ActiveModel::Serializer
  attributes :name, :public, :certificate_id
  belongs_to :district
end
