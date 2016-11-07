class AddAllowedAwsActionsToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :aws_actions, :text
  end
end
