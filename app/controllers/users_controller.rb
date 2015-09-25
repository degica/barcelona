class UsersController < ApplicationController
  skip_before_action :authenticate, only: [:login]

  def login
    github_token = request.headers['HTTP_X_GITHUB_TOKEN']
    user = User.login!(github_token)

    respond_to do |format|
      format.json { render json: {"login" => user.name, "token" => user.token}}
    end
  end
end
