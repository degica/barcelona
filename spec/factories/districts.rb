FactoryBot.define do
  factory :district do
    sequence :name do |n|
      "district#{n}"
    end
    region { 'us-east-1' }
    aws_access_key_id { "aws_access_key_id" }
    aws_secret_access_key { "aws_secret_access_key" }
  end
end
