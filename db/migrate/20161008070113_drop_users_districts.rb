class DropUsersDistricts < ActiveRecord::Migration
  def change
    drop_table :users_districts
  end
end
