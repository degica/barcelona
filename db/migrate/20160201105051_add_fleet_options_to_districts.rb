class AddFleetOptionsToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :cluster_backend, :string
    add_column :districts, :cluster_size, :integer
    add_column :districts, :cluster_instance_type, :string
  end
end
