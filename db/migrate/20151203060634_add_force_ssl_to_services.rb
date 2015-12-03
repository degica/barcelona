class AddForceSslToServices < ActiveRecord::Migration
  def change
    add_column :services, :force_ssl, :boolean
  end
end
