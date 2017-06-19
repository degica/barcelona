class AddAuthToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :auth, :string
  end
end
