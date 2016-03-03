class RemoveEncryptedAwsAccessKeyIdFromDistricts < ActiveRecord::Migration
  def change
    remove_column :districts, :encrypted_aws_access_key_id
  end
end
