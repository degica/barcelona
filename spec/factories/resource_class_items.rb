FactoryBot.define do
  factory :resource_class_item do
    resource_class
    
    name { "name" }
    type { "String" }
  end
end
