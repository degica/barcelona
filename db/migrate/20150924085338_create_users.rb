class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :token_hash

      t.timestamps null: false
    end

    add_index :users, :token_hash, unique: true
    add_index :users, :name, unique: true
  end
end
