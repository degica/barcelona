class AddHealthCheckToServices < ActiveRecord::Migration
  def change
    add_column :services, :health_check, :text
  end
end
