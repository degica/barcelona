class CreateOneoffs < ActiveRecord::Migration
  def change
    create_table :oneoffs do |t|
      t.string :task_arn
      t.references :heritage, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
