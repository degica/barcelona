require 'yaml'
require 'base64'
require 'gibberish'

module EncryptAttribute
  extend ActiveSupport::Concern

  def self.encrypt_attribute(value, secret_key, options)
    return nil if value.nil?

    value = serialize(value) if options[:serialize]
    value = encode(value)    if options[:encode]

    encrypt(value, secret_key)
  end

  def self.decrypt_attribute(value, secret_key, options)
    return nil if value.nil?

    decrypted = decrypt(value, secret_key)
    decrypted = decode(decrypted)      if options[:encode]
    decrypted = deserialize(decrypted) if options[:serialize]

    decrypted
  end

  def self.serialize(obj)
    YAML.dump(obj)
  end

  def self.deserialize(s)
    YAML.load(s)
  end

  def self.encode(s)
    Base64.encode64(s)
  end

  def self.decode(s)
    decoded = Base64.decode64(s)
    decoded.encode('UTF-8', 'UTF-8')
  end

  def self.encrypt(data, secret_key)
    # Gibberish's default encryption mode is aes-256-cbc
    # salt and iv(initialization vector) is automatically generated and embedded in encrypted value
    cipher = Gibberish::AES.new(secret_key)
    cipher.encrypt(data)
  end

  def self.decrypt(data, secret_key)
    cipher = Gibberish::AES.new(secret_key)
    cipher.decrypt(data)
  end

  module ClassMethods
    def encryption_targets
      @encryption_targets ||= {}
    end

    def default_encryption_options
      {
        encode: false,
        serialize: false
      }
    end

    def encrypted_attribute(name, options = {})
      encryption_targets[name.to_sym] = default_encryption_options.merge options

      define_method(name) do
        encrypted = send("encrypted_#{name}")
        secret_key = options[:secret_key].is_a?(Symbol) ? self.send(options[:secret_key]) : options[:secret_key]
        EncryptAttribute.decrypt_attribute(encrypted, secret_key, encryption_options_for(name))
      end

      define_method("#{name}=") do |val|
        secret_key = options[:secret_key].is_a?(Symbol) ? self.send(options[:secret_key]) : options[:secret_key]
        encrypted = EncryptAttribute.encrypt_attribute(val, secret_key, encryption_options_for(name))
        send("encrypted_#{name}=", encrypted)
      end

      define_method("#{name}?") do
        value = send(name)
        value.respond_to?(:empty?) ? !value.empty? : !!value
      end
    end
  end

  private

  def encryption_targets
    self.class.encryption_targets
  end

  def encryption_options_for(attr_name)
    encryption_targets[attr_name.to_sym]
  end
end
