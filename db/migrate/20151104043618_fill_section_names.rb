class FillSectionNames < ActiveRecord::Migration
  def change
    Heritage.all.each do |heritage|
      heritage.update(section_name: 'private')
    end
  end
end
