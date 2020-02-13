class CreatePermissions < ActiveRecord::Migration[5.2]
  def change
    create_table :permissions do |t|
      t.references :user, null: false
      t.string :key, null: false

      t.timestamps
    end
    add_index :permissions, [:user_id, :key], unique: true
  end
end
