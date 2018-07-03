FactoryBot.define do
  factory :user do
    sequence :name do |n|
      "user#{n}"
    end
    roles ["developer"]
    token { SecureRandom.hex }
  end
end
