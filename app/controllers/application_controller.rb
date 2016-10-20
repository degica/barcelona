class ApplicationController < ActionController::Base
  include Pundit

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  protect_from_forgery with: :null_session
  before_action :authenticate

  attr_accessor :current_user

  def authenticate
    @current_user = User.find_by_token(request.headers['HTTP_X_BARCELONA_TOKEN'])
    if @current_user.blank?
      raise ExceptionHandler::Unauthorized.new("User not found")
    end
  end

  # Add additional info to lograge logs
  def append_info_to_payload(payload)
    super
    payload[:user] = current_user.try(:name)
  end
end
