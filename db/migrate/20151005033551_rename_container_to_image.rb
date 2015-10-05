class RenameContainerToImage < ActiveRecord::Migration
  def change
    rename_column :heritages, :container_name, :image_name
    rename_column :heritages, :container_tag, :image_tag
  end
end
