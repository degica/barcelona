class EnvVar < ActiveRecord::Base
  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}

  before_save :encrypt_value

  def value
    return nil if encrypted_value.nil?
    cipher.decrypt(encrypted_value).to_s
  end

  def value=(v)
    if v.nil?
      self.encrypted_value = nil
    else
      self.encrypted_value = cipher.encrypt(v)
    end
    v
  end

  def encrypt_value
    if value
      self.encrypted_value = cipher.encrypt(value)
    end
  end

  private

  def cipher
    @cipher ||= Gibberish::AES.new(ENV['ENCRYPTION_KEY'])
  end
end
