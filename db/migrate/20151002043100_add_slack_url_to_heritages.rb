class AddSlackUrlToHeritages < ActiveRecord::Migration
  def change
    add_column :heritages, :slack_url, :text
  end
end
