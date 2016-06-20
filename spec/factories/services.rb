FactoryGirl.define do
  factory :service, class: 'Service' do
    sequence :name do |n|
      "service#{n}"
    end
    cpu 128
    memory 128
    public true
    association :app, factory: :app
  end

  factory :web_service, class: 'Service' do
    sequence :name do |n|
      "service#{n}"
    end
    service_type "web"
    cpu 128
    memory 128
    public true
    association :app, factory: :app
  end
end
