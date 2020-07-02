class ReviewAppSerializer < ActiveModel::Serializer
  attributes :domain, :subject

  belongs_to :review_group
  belongs_to :heritage
end
