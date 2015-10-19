class AddDockercfgToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :dockercfg, :text
  end
end
