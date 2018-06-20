class TransitSecret
  def initialize(district)
    @district = district
  end

  def create(data, adata = "")
    data_key = @district.generate_data_key
    enc = encrypt(key: data_key.plaintext, data: data, adata: adata)
    enc.merge!(ck: encode(data_key.ciphertext_blob)) # ck == ciphertext key
    encode(enc.to_json)
  end

  def encrypt(key:, data:, adata: "")
    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.auth_data = adata
    encrypted = cipher.update(data) + cipher.final
    atag = cipher.auth_tag
    {
      c: encode(encrypted),
      iv: encode(iv),
      t: encode(atag)
    }
  end

  private

  def encode(v)
    Base64.strict_encode64(v)
  end

  def decode(v)
    Base64.strict_decode64(v)
  end
end
