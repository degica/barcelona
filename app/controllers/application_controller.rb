class ApplicationController < ActionController::API
  before_action :authenticate
  before_action :authorize_action

  attr_accessor :current_user

  def authenticate
    @current_user = auth_backend.authenticate

    if @current_user.blank?
      raise ExceptionHandler::Unauthorized.new("User not found")
    end
  end

  def authorize_resource(*args)
    auth_backend.authorize_resource(*args)
  end

  def authorize_action(*args)
    auth_backend.authorize_action(*args)
  end

  # Add additional info to lograge logs
  def append_info_to_payload(payload)
    super
    payload[:user] = current_user.try(:name)
  end

  def auth_backend
    @auth_backend ||= auth_backend_class.new(request)
  end

  def auth_backend_class
    if VaultAuth.enabled?
      VaultAuth
    elsif GithubAuth.enabled?
      GithubAuth
    end
  end
end
