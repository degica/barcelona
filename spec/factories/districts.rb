FactoryGirl.define do
  factory :district do
    sequence :name do |n|
      "district#{n}"
    end
    aws_access_key_id "aws_access_key_id"
    aws_secret_access_key "aws_secret_access_key"
  end
end
