class CreateEndpoints < ActiveRecord::Migration
  def change
    create_table :endpoints do |t|
      t.references :district, index: true, foreign_key: true
      t.string :name
      t.boolean :public
      t.string :certificate_id
      t.timestamps null: false
    end

    add_index :endpoints, [:district_id, :name], unique: true
  end
end
