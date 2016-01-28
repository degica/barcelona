class RemoveSectionNameFromHeritages < ActiveRecord::Migration
  def change
    if Heritage.where(section_name: 'public').present?
      raise "Delete all public heritages first"
    end

    remove_column :heritages, :section_name
  end
end
