class AddSslPolicyToEndpoints < ActiveRecord::Migration[5.0]
  def change
    add_column :endpoints, :ssl_policy, :string
  end
end
