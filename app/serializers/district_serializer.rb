class DistrictSerializer < ActiveModel::Serializer
  attributes :name, :region, :s3_bucket_name, :container_instances,
             :stack_status, :nat_type, :cluster_size,
             :cidr_block, :stack_name, :bastion_ip,
             :aws_access_key_id, :aws_role,
             :auto_scaling_instance_types,
             :auto_scaling_on_demand_percentage,
             :auto_scaling_spot_instance_pools

  has_many :heritages
  has_many :plugins
  has_many :notifications
end
