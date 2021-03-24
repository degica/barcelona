class ResourceClass < ApplicationRecord
  has_many :resource_class_items, dependent: :destroy
  has_many :resource_instances

  validates :name, presence: true
  validates :name, uniqueness: true

  def self.build_from_hash(thehash)
    rc = ResourceClass.new
    rc.name = thehash.keys.first

    thehash.values.first['Properties'].each do |k, v|
      propdef = ResourceClassItem.new
      propdef.name = k
      propdef.valuetype = v['type']
      propdef.default = v['default'].to_s
      rc.resource_class_items << propdef
    end

    rc
  end
end
