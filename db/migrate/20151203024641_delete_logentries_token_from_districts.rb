class DeleteLogentriesTokenFromDistricts < ActiveRecord::Migration
  def change
    remove_column :districts, :logentries_token
  end
end
