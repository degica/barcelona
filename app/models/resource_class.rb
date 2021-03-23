class ResourceClass < ApplicationRecord
  has_many :resource_class_items
  has_many :resource_instances

  validates :name, presence: true
  validates :name, uniqueness: true
end
