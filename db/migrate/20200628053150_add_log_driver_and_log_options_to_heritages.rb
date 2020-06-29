class AddLogDriverAndLogOptionsToHeritages < ActiveRecord::Migration[5.2]
  def change
    add_column :heritages, :log_driver, :string
    add_column :heritages, :log_options, :text
  end
end
