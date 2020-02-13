FactoryBot.define do
  factory :permission do
    user
    key { 'district.show' }
  end
end
