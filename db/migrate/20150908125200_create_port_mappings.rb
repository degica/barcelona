class CreatePortMappings < ActiveRecord::Migration
  def change
    create_table :port_mappings do |t|
      t.integer :host_port
      t.integer :lb_port
      t.integer :container_port
      t.references :service, index: true, foreign_key: true

      t.timestamps null: false
    end

    add_index :port_mappings, :host_port, unique: true
  end
end
