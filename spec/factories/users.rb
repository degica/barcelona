FactoryGirl.define do
  factory :user do
    sequence :name do |n|
      "user#{n}"
    end
    token { SecureRandom.hex }
  end
end
