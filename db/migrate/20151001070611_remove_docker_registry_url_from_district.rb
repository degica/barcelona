class RemoveDockerRegistryUrlFromDistrict < ActiveRecord::Migration
  def change
    remove_column :districts, :docker_registry_url
  end
end
