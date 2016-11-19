class AddScheduledTasksToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :scheduled_tasks, :text
  end
end
