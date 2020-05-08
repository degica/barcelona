class AddWebContainerPortToService < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :web_container_port, :integer
  end
end
