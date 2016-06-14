class AddRegionToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :region, :string
  end
end
