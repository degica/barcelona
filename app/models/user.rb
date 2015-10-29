class User < ActiveRecord::Base
  ALLOWED_TEAMS = [
    {org: 'degica', team: 'developers', role: "developer"},
    {org: 'degica', team: 'Admin developers', role: "admin"},
  ]

  has_many :users_districts
  has_many :districts, through: :users_districts

  attr_accessor :token

  serialize :roles

  validates :name, presence: true, uniqueness: true

  before_validation :assign_districts
  before_save :hash_token
  after_save :update_instance_user_account

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
    ALLOWED_TEAMS.select do |t|
      t[:team] == team && t[:org] == org
    end.first.try(:[], :role)
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

  def update_instance_user_account
    if public_key.present? && public_key_changed?
      districts.each do |district|
        district.update_instance_user_account(self)
      end
    end
  end
end
