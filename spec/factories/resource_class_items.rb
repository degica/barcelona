FactoryBot.define do
  factory :resource_class_item do
    resource_class

    name { "name" }
    valuetype { "string" }
  end
end
