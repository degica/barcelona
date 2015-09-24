class CreateEnvVars < ActiveRecord::Migration
  def change
    create_table :env_vars do |t|
      t.references :heritage, index: true, foreign_key: true
      t.string :key
      t.string :value
    end

    add_index :env_vars, [:heritage_id, :key], unique: true
  end
end
