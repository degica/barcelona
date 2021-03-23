FactoryBot.define do
  factory :resource_instance_item do
    resource_instance
    resource_class_item

    value { "Sagrada Familia" }
  end
end
