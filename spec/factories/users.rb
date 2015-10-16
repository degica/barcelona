FactoryGirl.define do
  factory :user do
    name "kajihiro"
    token "dummy_token"
    token_hash Gibberish::SHA256("dummy_token")
  end
end
