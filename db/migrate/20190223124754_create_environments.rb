class CreateEnvironments < ActiveRecord::Migration[5.2]
  def change
    create_table :environments do |t|
      t.references :heritage, null: false, foreign_key: {on_delete: :cascade}
      t.string :name, null: false
      t.text :value
      t.text :value_from

      t.timestamps
    end
  end
end
