class ResourceInstanceItem < ApplicationRecord
  belongs_to :resource_instance
  belongs_to :resource_class_item

  validates :value, presence: true
  validates :resource_class_item, presence: true
  validates :resource_instance, presence: true
end
