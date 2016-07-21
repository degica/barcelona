class RemoveOldSerializedColumns < ActiveRecord::Migration
  def change
    remove_column :services, :old_hosts
    remove_column :services, :old_health_check
    remove_column :plugins, :old_plugin_attributes
  end
end
