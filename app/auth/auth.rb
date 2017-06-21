class Auth
  attr_accessor :request, :current_user

  def initialize(request)
    unless enabled?
      raise ExceptionHandler::InternalServerError.new("Auth backend is disabled")
    end
    @request = request
  end

  def authorize_resource(*args)
    raise ExceptionHandler::Unauthorized
  end
end
