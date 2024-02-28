class AddHookOrderToPlugin < ActiveRecord::Migration[5.2]
  def change
    add_column :plugins, :hook_priority, :integer, :default => 10
  end
end
