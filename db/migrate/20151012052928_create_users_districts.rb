class CreateUsersDistricts < ActiveRecord::Migration
  def change
    create_table :users_districts do |t|
      t.references :user, index: true, foreign_key: true
      t.references :district, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
