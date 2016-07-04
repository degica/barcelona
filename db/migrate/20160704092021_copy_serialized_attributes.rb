class CopySerializedAttributes < ActiveRecord::Migration
  def change
    add_column :services, :new_hosts, :text
    add_column :services, :new_health_check, :text
    add_column :plugins, :new_plugin_attributes, :text
  end
end
