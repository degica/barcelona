class CreateListeners < ActiveRecord::Migration
  def change
    create_table :listeners do |t|
      t.references :endpoint, index: true, foreign_key: true
      t.references :service, index: true, foreign_key: true
      t.integer :health_check_interval
      t.string :health_check_path
      t.text :rule_conditions
      t.integer :rule_priority

      t.timestamps null: false
    end

    add_index :listeners, [:endpoint_id, :service_id], unique: true
  end
end
