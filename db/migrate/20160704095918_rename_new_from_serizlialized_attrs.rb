class RenameNewFromSerizlializedAttrs < ActiveRecord::Migration
  def change
    remove_column :services, :hosts
    remove_column :services, :health_check

    rename_column :services, :new_hosts, :hosts
    rename_column :services, :new_health_check, :health_check

    remove_column :plugins, :plugin_attributes
    rename_column :plugins, :new_plugin_attributes, :plugin_attributes
  end
end
