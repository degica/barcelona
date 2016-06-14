class FillDefaultRegions < ActiveRecord::Migration
  def change
    District.update_all(region: 'ap-northeast-1')
  end
end
