class AddNatTypeToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :nat_type, :string
  end
end
