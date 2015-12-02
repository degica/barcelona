class AddHostsToServices < ActiveRecord::Migration
  def change
    add_column :services, :hosts, :text
  end
end
