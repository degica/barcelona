class DistrictSerializer < ActiveModel::Serializer
  attributes :name

  has_many :heritages
end
