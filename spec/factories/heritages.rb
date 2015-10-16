FactoryGirl.define do
  factory :heritage do
    name "dev"
    image_name "nginx"
    image_tag "1.9.5"
    association :district, factory: :district
  end
end
