class CreateServices < ActiveRecord::Migration
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.integer :cpu
      t.integer :memory
      t.string :command
      t.boolean :public
      t.references :heritage, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
