module AuthDriver
  class Github
    def initialize(token)
      @token = token
    end

    def login!
      unless belong_to_org?
        raise ExceptionHandler::Unauthorized.new("You are not allowed to login")
      end

      user = User.find_or_create_by!(name: client.user.login)
      user.github_token = @token
      user.generate_token
      user.save!
      user
    end

    def organizations
      client.organizations.map { |o| o.login }
    end

    def teams
      client.user_teams.
        select { |t| t.organization.login == organization }.
        map { |t| t.name }
    end

    def belong_to_org?
      organizations.include? organization
    end

    def organization
      ENV['GITHUB_ORGANIZATION']
    end

    private

    def client
      @client ||= Octokit::Client.new(access_token: @token)
    end
  end
end
