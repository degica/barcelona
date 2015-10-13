class User < ActiveRecord::Base
  ALLOWED_TEAM = {org: 'degica', team: 'developers'}
  has_many :users_districts
  has_many :districts, through: :users_districts

  attr_accessor :token

  validates :name, presence: true, uniqueness: true

  before_validation :assign_all_districts
  after_save :update_instance_user_account

  def self.login!(github_token)
    client = Octokit::Client.new(access_token: github_token)
    raise unless allowed_user?(client.user_teams)
    user = User.find_or_create_by!(name: client.user.login)
    user.new_token!
    user
  end

  def self.find_by_token(token)
    User.find_by(token_hash: Gibberish::SHA256(token))
  end

  def self.allowed_user?(user_teams)
    user_teams.any? { |t|
      t.name == ALLOWED_TEAM[:team] && t.organization.login == ALLOWED_TEAM[:org]
    }
  end

  def new_token!
    self.token = SecureRandom.hex(20)
    self.token_hash = Gibberish::SHA256(self.token)
    save!
  end

  private

  def assign_all_districts
    # Currently all users belong to all districts
    self.districts = District.all
  end

  def update_instance_user_account
    districts.each do |district|
      district.update_instance_user_account(self)
    end
  end
end
