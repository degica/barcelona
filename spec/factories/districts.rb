FactoryGirl.define do
  factory :district do
    sequence :name do |n|
      "district#{n}"
    end
    s3_bucket_name 'degica3-barcelona'
  end
end
