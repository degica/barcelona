class CreateReleases < ActiveRecord::Migration
  def change
    create_table :releases do |t|
      t.references :heritage, index: true, foreign_key: true
      t.text :description
      t.text :heritage_params
      t.integer :version
      t.timestamps null: false
    end
  end
end
