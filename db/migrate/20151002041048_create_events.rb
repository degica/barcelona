class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :uuid
      t.references :heritage, index: true, foreign_key: true
      t.text :message
      t.string :level

      t.timestamps null: false
    end
    add_index :events, :uuid, unique: true
  end
end
