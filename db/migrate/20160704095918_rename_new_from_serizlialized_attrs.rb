class RenameNewFromSerizlializedAttrs < ActiveRecord::Migration
  def change
    rename_column :services, :hosts, :old_hosts
    rename_column :services, :new_hosts, :hosts

    rename_column :services, :health_check, :old_health_check
    rename_column :services, :new_health_check, :health_check

    rename_column :plugins, :plugin_attributes, :old_plugin_attributes
    rename_column :plugins, :new_plugin_attributes, :plugin_attributes
  end
end
