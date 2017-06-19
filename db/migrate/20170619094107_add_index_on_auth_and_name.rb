class AddIndexOnAuthAndName < ActiveRecord::Migration[5.0]
  def change
    remove_index :users, name: "index_users_on_name"
    add_index :users, [:name, :auth], unique: true
  end
end
