class ChangeCommandColumnToText < ActiveRecord::Migration
  def change
    change_column :services, :command, :text
  end
end
