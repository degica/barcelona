class UsersController < ApplicationController
  skip_before_action :authenticate, only: [:login]
  before_action :load_user, except: [:index, :login]

  def login
    user = auth_backend.login
    raise ExceptionHandler::Unauthorized.new("You are not allowed to login") if user.nil?

    user.permissions.create!(key: 'users.edit')
    user.save!

    Event.new.notify(message: "#{user.name} has logged in to Barcelona")

    render json: user
  end

  def index
    users = User.all
    render json: users
  end

  def show
    render json: @user
  end

  def update
    current_user.update(update_params)
    render json: current_user
  end

  private

  def load_user
    @user = if params[:id].present?
              User.find_by!(name: params[:id])
            else
              current_user
            end
    authorize_resource @user
  end

  def update_params
    params.permit [
      :public_key
    ]
  end
end
