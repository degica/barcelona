class CreateResourceInstanceItems < ActiveRecord::Migration[5.2]
  def change
    create_table :resource_instance_items do |t|
      t.string :value
      t.references :resource_instance, foreign_key: true, null: false
      t.references :resource_class_item, foreign_key: true, null: false

      t.timestamps
    end
  end
end
