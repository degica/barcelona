module Support
  module GithubStub
    def stub_github_auth(user_name: 'user', org: 'degica', teams: [])
      ENV['GITHUB_ORGANIZATION'] = org
      org_double = double(login: org)
      github_stub = double(
        user: double(login: user_name),
        organizations: [org_double],
        user_teams: teams.map { |t| double(organization: org_double, name: t)}
      )
      allow(Octokit::Client).to receive(:new) { github_stub }
    end
  end
end
