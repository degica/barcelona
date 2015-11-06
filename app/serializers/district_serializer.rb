class DistrictSerializer < ActiveModel::Serializer
  attributes :name, :vpc_id, :public_elb_security_group, :private_elb_security_group, :instance_security_group, :ecs_service_role, :ecs_instance_role, :private_hosted_zone_id, :s3_bucket_name, :container_instances, :logentries_token

  has_many :heritages
  has_many :plugins
end
