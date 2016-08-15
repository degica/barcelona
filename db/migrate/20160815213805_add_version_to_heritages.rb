class AddVersionToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :version, :integer
  end
end
