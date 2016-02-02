class FillClusterOptions < ActiveRecord::Migration
  def change
    District.all.each do |district|
      district.save!
    end
  end
end
