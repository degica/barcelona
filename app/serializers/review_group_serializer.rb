class ReviewGroupSerializer < ActiveModel::Serializer
  attributes :name, :base_domain, :token

  has_many :review_apps
  has_one :endpoint
end
