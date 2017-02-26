FactoryGirl.define do
  factory :notification do
    target "slack"
    endpoint "https://hooks.slack.com/services/aaaaa/bbbb"
  end
end
