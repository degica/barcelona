class ResourceClassItem < ApplicationRecord
  belongs_to :resource_class

  validates :name, presence: true
  validates :valuetype, presence: true
  validates :resource_class, presence: true

  validates :valuetype, inclusion: { in: %w[boolean string integer] }, unless: :type_is_resource_class?
  
  validates :default, inclusion: { in: %w[true false] }, allow_nil: true, if: :boolean?
  validates :default, numericality: true, allow_nil: true, if: :integer?
  validates :default, absence: true, if: :type_is_resource_class?

  def optional?
    default.present?
  end

  def type_is_resource_class?
    ResourceClass.exists?(name: valuetype)
  end

  def boolean?
    valuetype == 'boolean'
  end

  def integer?
    valuetype == 'integer'
  end
end
