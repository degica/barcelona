class EnvVar < ActiveRecord::Base
  include EncryptAttribute

  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}

  encrypted_attribute :value, secret_key: ENV['ENCRYPTION_KEY']
end
