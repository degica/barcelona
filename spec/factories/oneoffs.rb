FactoryBot.define do
  factory :oneoff do
    command { 'ls -l' }
    association :heritage
  end
end
