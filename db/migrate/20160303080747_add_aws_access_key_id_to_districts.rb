class AddAwsAccessKeyIdToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :aws_access_key_id, :string
  end
end
