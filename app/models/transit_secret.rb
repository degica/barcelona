class TransitSecret
  def initialize(district)
    @district = district
  end

  def create(data, adata = "")
    data_key = @district.generate_data_key
    enc = encrypt(key: data_key.plaintext, data: data, adata: adata)
    "bcn:transit:v1:#{encode(data_key.ciphertext_blob)}:#{encode(enc)}"
  end

  def encrypt(key:, data:, adata: "")
    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.auth_data = adata
    encrypted = cipher.update(data) + cipher.final
    atag = cipher.auth_tag

    # This encrypted value is eventually decrpyted by barcelona run pack which is
    # written in golang and golang's aes lib expects atag to be appended at the tail of ciphertext
    # See https://jg.gg/2018/01/22/communicating-via-aes-256-gcm-between-nodejs-and-golang/
    iv + encrypted + atag
  end

  private

  def encode(v)
    Base64.strict_encode64(v)
  end

  def decode(v)
    Base64.strict_decode64(v)
  end
end
