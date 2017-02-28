class DistrictSerializer < ActiveModel::Serializer
  attributes :name, :region, :s3_bucket_name, :container_instances,
             :stack_status, :nat_type, :cluster_size, :cluster_instance_type,
             :cluster_backend, :cidr_block, :stack_name, :bastion_ip,
             :aws_access_key_id, :aws_role

  has_many :heritages
  has_many :plugins
end
