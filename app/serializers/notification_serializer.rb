class NotificationSerializer < ActiveModel::Serializer
  attributes :id, :target, :endpoint
  belongs_to :district
end
