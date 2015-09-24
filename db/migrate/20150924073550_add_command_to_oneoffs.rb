class AddCommandToOneoffs < ActiveRecord::Migration
  def change
    add_column :oneoffs, :command, :text
  end
end
