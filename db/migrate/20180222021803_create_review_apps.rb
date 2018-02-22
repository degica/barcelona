class CreateReviewApps < ActiveRecord::Migration[5.1]
  def change
    create_table :review_apps do |t|
      t.references :heritage, foreign_key: true
      t.string :subject
      t.string :base_domain
      t.string :group

      t.timestamps
    end
  end
end
