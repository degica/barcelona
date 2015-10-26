class AddRolesToUsers < ActiveRecord::Migration
  def change
    add_column :users, :roles, :text
  end
end
