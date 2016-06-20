class RenameHeritagesToApps < ActiveRecord::Migration
  def change
    rename_table :heritages, :apps
    rename_column :env_vars, :heritage_id, :app_id
    rename_column :events, :heritage_id, :app_id
    rename_column :oneoffs, :heritage_id, :app_id
    rename_column :releases, :heritage_id, :app_id
    rename_column :releases, :heritage_params, :app_params
    rename_column :services, :heritage_id, :app_id
  end
end
