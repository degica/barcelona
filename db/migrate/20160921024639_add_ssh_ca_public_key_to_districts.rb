class AddSshCaPublicKeyToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :ssh_ca_public_key, :text
  end
end
