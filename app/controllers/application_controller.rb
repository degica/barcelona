class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  before_action :authenticate

  def authenticate
    @current_user = User.find_by_token(request.headers['HTTP_X_BARCELONA_TOKEN'])
    raise "user not found" if @current_user.blank?
  end
end
