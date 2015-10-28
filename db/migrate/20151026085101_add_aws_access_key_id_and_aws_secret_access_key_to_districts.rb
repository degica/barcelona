class AddAwsAccessKeyIdAndAwsSecretAccessKeyToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :encrypted_aws_access_key_id, :text
    add_column :districts, :encrypted_aws_secret_access_key, :text
  end
end
