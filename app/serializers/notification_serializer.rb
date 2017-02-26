class NotificationSerializer < ActiveModel::Serializer
  attributes :target, :endpoint
  belongs_to :district
end
