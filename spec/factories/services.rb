FactoryBot.define do
  factory :service, class: 'Service' do
    sequence :name do |n|
      "service#{n}"
    end
    cpu 128
    memory 128
    public true
    command "rails s"
    association :heritage, factory: :heritage
  end

  factory :web_service, class: 'Service' do
    sequence :name do |n|
      "service#{n}"
    end
    service_type "web"
    cpu 128
    memory 128
    public true
    command "rails s"
    association :heritage, factory: :heritage
  end
end
