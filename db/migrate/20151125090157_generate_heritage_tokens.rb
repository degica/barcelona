class GenerateHeritageTokens < ActiveRecord::Migration
  def change
    Heritage.all.each do |heritage|
      heritage.regenerate_token
      heritage.save!
    end
  end
end
