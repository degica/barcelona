class User < ActiveRecord::Base
  has_many :users_districts
  has_many :permissions

  attr_accessor :token

  serialize :roles

  validates :name, presence: true, uniqueness: true

  before_save :hash_token

  def self.find_by_token(token)
    User.find_by(token_hash: Gibberish::SHA256(token))
  end

  def generate_new_token
    self.token = SecureRandom.hex(20)
  end

  def admin?
    roles.include? "admin"
  end

  def developer?
    roles.include?("developer") || roles.include?("admin")
  end

  def to_param
    name
  end

  def allowed_to?(*args)
    return true if admin?
    return true if permissions.exists?(key: args.join('.'))

    false
  end

  private

  def hash_token
    self.token_hash = Gibberish::SHA256(self.token) if token.present?
  end
end
