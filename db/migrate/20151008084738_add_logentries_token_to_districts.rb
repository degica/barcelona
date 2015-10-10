class AddLogentriesTokenToDistricts < ActiveRecord::Migration
  def change
    add_column :districts, :logentries_token, :string
  end
end
