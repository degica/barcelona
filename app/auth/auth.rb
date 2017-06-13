class Auth
  attr_accessor :request, :current_user

  def initialize(request)
    @request = request
  end

  def authorize_resource(*args)
    raise ExceptionHandler::Unauthorized
  end
end
