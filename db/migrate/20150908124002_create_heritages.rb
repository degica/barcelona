class CreateHeritages < ActiveRecord::Migration
  def change
    create_table :heritages do |t|
      t.string :name, null: false
      t.string :container_name
      t.string :container_tag
      t.references :district, index: true, foreign_key: true

      t.timestamps null: false
    end

    add_index :heritages, :name, unique: true
  end
end
