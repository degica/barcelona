class UnencryptAwsAccessKeyId < ActiveRecord::Migration
  def change
    District.find_each do |district|
      encrypted = district.encrypted_aws_access_key_id
      decrypted = EncryptAttribute.decrypt_attribute(
        encrypted,
        ENV['ENCRYPTION_KEY'],
        {}
      )
      district.aws_access_key_id = decrypted
      district.save!
    end
  end
end
