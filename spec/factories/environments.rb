FactoryBot.define do
  factory :environment do
    name { "ENV" }
    value { "VALUE" }
    association :heritage
  end

  factory :secret_environment, class: "Environment" do
    name { "ENV" }
    value_from { "/production/database_url" }
    association :heritage
  end
end
