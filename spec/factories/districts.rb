FactoryGirl.define do
  factory :district do
    sequence :name do |n|
      "district#{n}"
    end
  end
end
