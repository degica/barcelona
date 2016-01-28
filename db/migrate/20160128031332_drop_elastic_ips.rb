class DropElasticIps < ActiveRecord::Migration
  def change
    drop_table :elastic_ips
  end
end
