class User < ActiveRecord::Base
  attr_accessor :token

  validates :name, presence: true, uniqueness: true

  before_save :hash_token

  def self.find_by_token(token)
    User.find_by(token_hash: Gibberish::SHA256(token))
  end

  def generate_token
    self.token = SecureRandom.hex(20)
  end

  def to_param
    name
  end

  def district_admin?(district)
    district_role(district) == :admin
  end

  def district_developer?(district)
    role = district_role(district)
    role == :developer || role == :admin
  end

  def district_role(district)
    auth = AuthDriver::Github.new(github_token)
    teams = auth.teams
    if teams.include? district.admin_team
      :admin
    elsif teams.include? district.developer_team
      :developer
    elsif district.developer_team.nil? && district.admin_team.nil?
      :admin
    end
  end

  private

  def hash_token
    self.token_hash = Gibberish::SHA256(self.token) if token.present?
  end
end
