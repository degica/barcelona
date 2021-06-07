class GithubAuth < Auth
  def self.enabled?
    ENV['GITHUB_ORGANIZATION'].present?
  end

  def login
    github_token = request.headers['HTTP_X_GITHUB_TOKEN']

    client = Octokit::Client.new(access_token: github_token)
    roles = user_roles(client.user_teams)

    if roles.present?
      user = User.find_or_create_by!(name: client.user.login)
      user.generate_new_token
      user.roles = roles
      user
    end
  end

  def authenticate
    @current_user = User.find_by_token(request.headers['HTTP_X_BARCELONA_TOKEN'])
  end

  def authorize_resource(record, query = nil)
    query ||= request.params[:action].to_s + "?"
    Pundit.authorize(current_user, record, query)
  end

  # Ignore action based authorization
  def authorize_action(*args); end

  private

  def user_roles(user_teams)
    user_teams.map{ |t| roles_for(team: t.name, org: t.organization.login) }.flatten.uniq.compact
  end

  def roles_for(team:, org:)
    allowed_teams.select { |t|
      (t[:team] == team || t[:team].nil?) && t[:org] == org
    }.map { |t| t[:role] }
  end

  def allowed_teams
    [
      {org: ENV['GITHUB_ORGANIZATION'], team: ENV['GITHUB_DEVELOPER_TEAM'], role: "developer"},
      {org: ENV['GITHUB_ORGANIZATION'], team: ENV['GITHUB_ADMIN_TEAM'], role: "admin"}
    ]
  end
end
