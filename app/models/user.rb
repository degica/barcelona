class User < ActiveRecord::Base
  ALLOWED_TEAM = {org: 'degica', team: 'developers'}

  attr_accessor :token

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
end
