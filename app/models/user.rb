class User < ActiveRecord::Base
  if Rails.env.development?
    class Fake
      def admin?
        true
      end

      def developer?
        true
      end
    end
  end

  ALLOWED_TEAMS = [
    {org: 'degica', team: 'developers', role: "developer"},
    {org: 'degica', team: 'Admin developers', role: "admin"}
  ]

  has_many :users_districts
  has_many :districts, through: :users_districts

  attr_accessor :token

  serialize :roles

  validates :name, presence: true, uniqueness: true

  before_validation :assign_districts
  before_save :hash_token

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
    user_teams.map{ |t| role_for(team: t.name, org: t.organization.login) }.compact
  end

  def self.role_for(team:, org:)
    ALLOWED_TEAMS.find { |t|
      t[:team] == team && t[:org] == org
    }&.dig(:role)
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

  def instance_groups
    groups = []
    groups << "docker" if developer?
    groups << "wheel"  if admin?
    groups
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
