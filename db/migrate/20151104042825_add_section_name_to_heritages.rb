class AddSectionNameToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :section_name, :string
  end
end
