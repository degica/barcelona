FactoryBot.define do
  factory :review_group do
    name { "review" }
    base_domain { "review.basedomain.com"}
    association :endpoint
  end
end
