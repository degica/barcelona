class RemoveSlackUrlFromHeritages < ActiveRecord::Migration[5.0]
  def change
    remove_column :heritages, :slack_url
  end
end
