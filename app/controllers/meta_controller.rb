class MetaController < ApplicationController
  skip_before_action :authenticate
  skip_before_action :authorize_action

  def index
    res = { auth: { backend: auth_backend.name } }
    case auth_backend.name 
    when "vault"
      res[:auth][:vault] = {
        url: ENV["VAULT_URL"]
      }
    when "github"
      res[:auth][:github] = {
        organization: ENV["GITHUB_ORGANIZATION"],
        developer_team: ENV['GITHUB_DEVELOPER_TEAM'],
        admin_team: ENV['GITHUB_ADMIN_TEAM'],
      }
    end

    render json: res
  end
end
