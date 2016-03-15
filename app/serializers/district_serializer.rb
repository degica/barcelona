class DistrictSerializer < ActiveModel::Serializer
  attributes :name, :vpc_id, :public_elb_security_group, :private_elb_security_group,
             :instance_security_group, :ecs_service_role, :ecs_instance_profile,
             :private_hosted_zone_id, :s3_bucket_name, :container_instances,
             :stack_status, :nat_type, :cluster_size, :cluster_instance_type,
             :cluster_backend, :cidr_block, :stack_name, :bastion_key_pair, :bastion_ip,
             :aws_access_key_id

  has_many :heritages
  has_many :plugins
end
