FactoryGirl.define do
  factory :elastic_ip do
    association :district, factory: :district
    allocation_id "allocation_id"
  end
end
