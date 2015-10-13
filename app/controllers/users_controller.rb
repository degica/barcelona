class UsersController < ApplicationController
  skip_before_action :authenticate, only: [:login]

  def login
    github_token = request.headers['HTTP_X_GITHUB_TOKEN']
    user = User.login!(github_token)

    respond_to do |format|
      format.json { render json: {"login" => user.name, "token" => user.token}}
    end
  end

  def show
    render json: current_user
  end

  def update
    current_user.update(update_params)
    render json: current_user
  end

  private

  def update_params
    params.permit [
      :public_key
    ]
  end
end
