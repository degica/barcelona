class CreateResourceClasses < ActiveRecord::Migration[5.2]
  def change
    create_table :resource_classes do |t|
      t.string :name

      t.timestamps
    end
    add_index :resource_classes, :name, unique: true
  end
end
