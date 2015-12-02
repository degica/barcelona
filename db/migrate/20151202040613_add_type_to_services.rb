class AddTypeToServices < ActiveRecord::Migration
  def change
    add_column :services, :service_type, :string, default: "default"
  end
end
