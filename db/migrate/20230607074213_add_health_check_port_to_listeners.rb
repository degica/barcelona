class AddHealthCheckPortToListeners < ActiveRecord::Migration[5.2]
  def change
    add_column :listeners, :health_check_port, :string
  end
end
