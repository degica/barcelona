class AddTokenToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :token, :string
  end
end
