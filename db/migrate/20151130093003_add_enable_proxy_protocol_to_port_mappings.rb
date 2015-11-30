class AddEnableProxyProtocolToPortMappings < ActiveRecord::Migration
  def change
    add_column :port_mappings, :enable_proxy_protocol, :boolean, default: false
  end
end
