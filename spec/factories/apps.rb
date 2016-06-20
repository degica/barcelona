FactoryGirl.define do
  factory :app do
    sequence :name do |n|
      "app#{n}"
    end
    image_name "nginx"
    image_tag "1.9.5"
    association :district, factory: :district
  end
end
