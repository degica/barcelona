class ApplicationController < ActionController::API
  include Pundit

  before_action :authenticate

  attr_accessor :current_user

  def authenticate
    @current_user = User.find_by_token(request.headers['HTTP_X_BARCELONA_TOKEN'])
    @current_user ||= User::Fake.new if Rails.env.development?
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
