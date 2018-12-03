FactoryBot.define do
  factory :heritage do
    sequence :name do |n|
      "heritage#{n}"
    end
    image_name { "nginx" }
    image_tag { "1.9.5" }
    association :district, factory: :district
  end
end
