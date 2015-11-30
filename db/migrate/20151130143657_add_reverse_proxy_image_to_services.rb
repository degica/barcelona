class AddReverseProxyImageToServices < ActiveRecord::Migration
  def change
    add_column :services, :reverse_proxy_image, :string
  end
end
