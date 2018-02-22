class ReviewAppSerializer < ActiveModel::Serializer
  attributes :domain, :subject, :group, :base_domain

  belongs_to :heritage
end
