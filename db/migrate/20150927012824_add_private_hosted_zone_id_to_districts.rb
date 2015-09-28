class AddPrivateHostedZoneIdToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :private_hosted_zone_id, :string
  end
end
