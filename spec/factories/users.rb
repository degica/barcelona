FactoryGirl.define do
  factory :user do
    name "kajihiro"
    roles ["developer"]
    token { SecureRandom.hex }
  end
end
