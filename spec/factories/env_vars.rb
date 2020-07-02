FactoryBot.define do
  factory :env_var do
    key { "KEY" }
    value { "VALUE" }
    secret { false }
    association :heritage
  end
end
