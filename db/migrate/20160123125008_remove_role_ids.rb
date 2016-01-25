class RemoveRoleIds < ActiveRecord::Migration
  def change
    remove_column :districts, :ecs_service_role
    remove_column :districts, :ecs_instance_role
  end
end
