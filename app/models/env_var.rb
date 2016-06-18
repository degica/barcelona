class EnvVar < ActiveRecord::Base
  include EncryptAttribute

  belongs_to :app

  validates :key, uniqueness: {scope: :app_id}
  validates :key, :value, presence: true

  encrypted_attribute :value, secret_key: ENV['ENCRYPTION_KEY']

  def value_with_to_s
    value_without_to_s.to_s
  end
  alias_method_chain :value, :to_s
end
