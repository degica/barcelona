class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.string :target, null: false
      t.string :endpoint, null: false
      t.references :district, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
