class RemoveIndexOnPortMappingHostPort < ActiveRecord::Migration
  def change
    remove_index :port_mappings, name: "index_port_mappings_on_host_port"
  end
end
