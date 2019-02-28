class CreateReviewApps < ActiveRecord::Migration[5.1]
  def change
    create_table :review_apps do |t|
      t.references :heritage, foreign_key: true, index: {unique: true}, null: false
      t.references :review_group, foreign_key: true, null: false
      t.string :subject, null: false

      t.timestamps
    end
  end
end
