class CreateServiceDeployments < ActiveRecord::Migration[5.2]
  def change
    create_table :service_deployments do |t|
      t.references :service, foreign_key: true, null: false
      t.datetime :completed_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :service_deployments, [:completed_at, :failed_at]
  end
end
