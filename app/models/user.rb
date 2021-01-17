class User < ActiveRecord::Base
  has_many :users_districts

  attr_accessor :token

  serialize :roles

  validates :name, presence: true, uniqueness: { scope: :auth }

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

  private

  def hash_token
    self.token_hash = Gibberish::SHA256(self.token) if token.present?
  end
end
