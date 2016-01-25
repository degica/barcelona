FactoryGirl.define do
  factory :district do
    sequence :name do |n|
      "district#{n}"
    end
    vpc_id "vpc-46f84523"
    public_elb_security_group 'sg-71307914'
    private_elb_security_group 'sg-71307914'
    instance_security_group 'sg-3b327b5e'
    ecs_service_role 'ecsServiceRole'
    ecs_instance_profile 'ecsInstanceRole'
    private_hosted_zone_id 'Z2MY4ND3Z2EPA2'
    s3_bucket_name 'degica3-barcelona'
  end
end
