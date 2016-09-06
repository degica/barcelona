class AddSecretIdToEnvVars < ActiveRecord::Migration
  def change
    add_column :env_vars, :secret, :boolean, default: false
  end
end
