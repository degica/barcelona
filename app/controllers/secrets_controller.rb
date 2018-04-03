class SecretsController < ApplicationController
  before_action :load_district

  def create
    data_key = @district.generate_data_key
  end

  private

  def encrypt(key, data, adata)
    cipher = OpenSSL::Cipher.new('AES-256-GCM')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.auth_data = adata
    encrypted = cipher.update(data) + cipher.final
    atag = cipher.auth_tag
    {
      encrypted: encrypted,
      iv: iv,
      atag: atag,
      adata: adata
    }
  end

  def decrypt(encrypted:, key:, iv:, atag:, adata:)
    cipher = OpenSSL::Cipher.new('AES-256-GCM')
    cipher.decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = atag
    cipher.auth_data = adata
    decrypted = cipher.update(content) + cipher.final
    decrypted
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
