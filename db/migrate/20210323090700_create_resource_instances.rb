class CreateResourceInstances < ActiveRecord::Migration[5.2]
  def change
    create_table :resource_instances do |t|
      t.string :name
      t.references :resource_class, foreign_key: true, null: false

      t.timestamps
    end
    add_index :resource_instances, :name, unique: true
  end
end
