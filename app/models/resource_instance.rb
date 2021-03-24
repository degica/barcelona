class ResourceInstance < ApplicationRecord
  belongs_to :resource_class
  belongs_to :district
  has_many :resource_instance_items

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :resource_class, presence: true
  validates :district, presence: true
end
