class AddBeforeDeployToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :before_deploy, :text
  end
end
