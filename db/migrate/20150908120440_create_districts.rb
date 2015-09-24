class CreateDistricts < ActiveRecord::Migration
  def change
    create_table :districts do |t|
      t.string :name
      t.string :vpc_id
      t.string :public_elb_security_group
      t.string :private_elb_security_group
      t.string :instance_security_group
      t.string :ecs_service_role
      t.string :ecs_instance_role
      t.string :docker_registry_url

      t.timestamps null: false
    end
  end
end
