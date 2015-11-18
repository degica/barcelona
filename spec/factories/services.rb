FactoryGirl.define do
  factory :web_service, class: 'Service' do
    sequence :name do |n|
      "service#{n}"
    end
    cpu 128
    memory 128
    public true
    association :heritage, factory: :heritage
  end
end
