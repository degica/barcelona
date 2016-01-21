class AddCidrBlockAndBastionKeyPairToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :cidr_block, :string
    add_column :districts, :bastion_key_pair, :string
    add_column :districts, :stack_name, :string
  end
end
