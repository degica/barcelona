class CreatePlugins < ActiveRecord::Migration
  def change
    create_table :plugins do |t|
      t.text :plugin_attributes
      t.references :district, index: true, foreign_key: true
      t.string :name

      t.timestamps null: false
    end
  end
end
