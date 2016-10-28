FactoryGirl.define do
  factory :endpoint do
    sequence :name do |n|
      "endpoint#{n}"
    end
    public true
    certificate_id "certificate_id"
    association :district, factory: :district
  end
end
