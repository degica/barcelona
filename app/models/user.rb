class User < ActiveRecord::Base
  has_many :users_districts
  has_many :districts, through: :users_districts

  attr_accessor :token

  serialize :roles

  validates :name, presence: true, uniqueness: true

  before_validation :assign_districts
  before_save :hash_token

  def self.allowed_teams
    [
      {org: ENV['GITHUB_ORGANIZATION'], team: ENV['GITHUB_DEVELOPER_TEAM'], role: "developer"},
      {org: ENV['GITHUB_ORGANIZATION'], team: ENV['GITHUB_ADMIN_TEAM'], role: "admin"}
    ]
  end

  def self.login!(github_token)
    client = Octokit::Client.new(access_token: github_token)
    roles = user_roles(client.user_teams)
    raise ExceptionHandler::Unauthorized.new("You are not allowed to login") if roles.blank?

    user = User.find_or_create_by!(name: client.user.login)
    user.roles = roles
    user.new_token!
    user
  end

  def self.find_by_token(token)
    User.find_by(token_hash: Gibberish::SHA256(token))
  end

  def self.user_roles(user_teams)
    user_teams.map{ |t| roles_for(team: t.name, org: t.organization.login) }.flatten.uniq.compact
  end

  def self.roles_for(team:, org:)
    allowed_teams.select { |t|
      (t[:team] == team || t[:team] == nil) && t[:org] == org
    }.map { |t| t[:role] }
  end

  def new_token!
    self.token = SecureRandom.hex(20)
    save!
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

  def assign_districts
    # Currently all users belong to all districts
    self.districts = District.all
  end
end
