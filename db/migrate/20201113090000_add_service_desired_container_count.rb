class AddServiceDesiredContainerCount < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :desired_container_count, :integer
  end
end
