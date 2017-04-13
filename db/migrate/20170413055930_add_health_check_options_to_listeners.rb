class AddHealthCheckOptionsToListeners < ActiveRecord::Migration[5.0]
  def change
    add_column :listeners, :health_check_timeout, :integer
    add_column :listeners, :healthy_threshold_count, :integer
    add_column :listeners, :unhealthy_threshold_count, :integer
  end
end
