class AddProtocolToPortMappings < ActiveRecord::Migration
  def change
    add_column :port_mappings, :protocol, :string
  end
end
