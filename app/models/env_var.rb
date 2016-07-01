class EnvVar < ActiveRecord::Base
  module ValueToString
    def value
      super.to_s
    end
  end
  include EncryptAttribute
  prepend ValueToString

  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}
  validates :key, :value, presence: true

  encrypted_attribute :value, secret_key: ENV['ENCRYPTION_KEY']
end
