class DropEvents < ActiveRecord::Migration[5.0]
  def change
    drop_table :events
  end
end
