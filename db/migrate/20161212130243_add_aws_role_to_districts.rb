class AddAwsRoleToDistricts < ActiveRecord::Migration[5.0]
  def change
    add_column :districts, :aws_role, :string
  end
end
