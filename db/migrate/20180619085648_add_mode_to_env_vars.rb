class AddModeToEnvVars < ActiveRecord::Migration[5.1]
  def change
    add_column :env_vars, :mode, :string
  end
end
