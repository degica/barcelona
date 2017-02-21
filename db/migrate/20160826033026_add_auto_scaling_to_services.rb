class AddAutoScalingToServices < ActiveRecord::Migration
  def change
    add_column :services, :auto_scaling, :text
  end
end
