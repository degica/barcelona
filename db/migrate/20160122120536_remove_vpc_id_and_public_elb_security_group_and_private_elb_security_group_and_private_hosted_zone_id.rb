class RemoveVpcIdAndPublicElbSecurityGroupAndPrivateElbSecurityGroupAndPrivateHostedZoneId < ActiveRecord::Migration
  def change
    remove_column :districts, :vpc_id
    remove_column :districts, :public_elb_security_group
    remove_column :districts, :private_elb_security_group
    remove_column :districts, :instance_security_group
    remove_column :districts, :private_hosted_zone_id
  end
end
