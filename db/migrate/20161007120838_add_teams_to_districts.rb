class AddTeamsToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :admin_team, :string
    add_column :districts, :developer_team, :string
  end
end
