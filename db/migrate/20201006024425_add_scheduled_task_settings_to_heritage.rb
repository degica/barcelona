class AddScheduledTaskSettingsToHeritage < ActiveRecord::Migration[5.2]
  def change
    add_column :heritages, :scheduled_task_cpu, :integer, null: false, default: 128
    add_column :heritages, :scheduled_task_memory, :integer, null: false, default: 512
  end
end
