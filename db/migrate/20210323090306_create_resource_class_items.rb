class CreateResourceClassItems < ActiveRecord::Migration[5.2]
  def change
    create_table :resource_class_items do |t|
      t.string :name
      t.string :valuetype
      t.string :default
      t.references :resource_class, foreign_key: true, null: false

      t.timestamps
    end
  end
end
