class FillInDefaultVersion < ActiveRecord::Migration
  def change
    Heritage.update_all(version: 1)
  end
end
