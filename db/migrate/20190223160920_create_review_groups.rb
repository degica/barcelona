class CreateReviewGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :review_groups do |t|
      t.references :endpoint, foreign_key: true, null: false
      t.string :name, null: false
      t.string :base_domain, null: false
      t.string :token, null: false

      t.timestamps
    end

    add_index :review_groups, :name, unique: true
    add_index :review_groups, :token, unique: true
  end
end
