class AddAutoScalingColumnsToDistricts < ActiveRecord::Migration[5.2]
  def change
    add_column :districts, :auto_scaling_on_demand_percentage, :integer, null: false, default: 100
    add_column :districts, :auto_scaling_spot_instance_pools, :integer, null: false, default: 2
    add_column :districts, :auto_scaling_instance_types, :text
  end
end
