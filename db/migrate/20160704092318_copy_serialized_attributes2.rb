class CopySerializedAttributes2 < ActiveRecord::Migration
  def change
    Service.all.each do |service|
      service.new_hosts = service.hosts
      service.new_health_check = service.health_check
      service.save!
    end
    Plugin.all.each do |plugin|
      plugin.new_plugin_attributes = plugin.plugin_attributes
      plugin.save!
    end
  end
end
