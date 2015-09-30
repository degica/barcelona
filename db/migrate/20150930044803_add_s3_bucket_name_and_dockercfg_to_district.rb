class AddS3BucketNameAndDockercfgToDistrict < ActiveRecord::Migration
  def change
    add_column :districts, :s3_bucket_name, :string
  end
end
