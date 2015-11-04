class CreateElasticIps < ActiveRecord::Migration
  def change
    create_table :elastic_ips do |t|
      t.string :allocation_id
      t.references :district, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
