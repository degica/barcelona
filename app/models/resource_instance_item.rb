class ResourceInstanceItem < ApplicationRecord
  belongs_to :resource_instance
  belongs_to :resource_class_item

  validates :value, presence: true
  validates :resource_class_item, presence: true
  validates :resource_instance, presence: true

  validate :validate_with_class_item

  def name
    resource_class_item.name
  end

  def validate_with_class_item
    return if resource_class_item.nil?
    return if resource_instance.nil?
    
    if resource_class_item.resource_class != resource_instance.resource_class
      errors.add(:resource_class_item, "#{resource_instance.name} #{resource_class_item.name} does not belong to this resource class #{resource_class_item.resource_class}")
    end
  end
end
