class ResourceClassItem < ApplicationRecord
  belongs_to :resource_class

  validates :name, presence: true
  validates :type, presence: true
  validates :resource_class, presence: true

  def type_is_resource_class?

  end

end
