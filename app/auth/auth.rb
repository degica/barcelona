class Auth
  attr_accessor :request, :current_user

  def initialize(request)
    unless self.class.enabled?
      raise ExceptionHandler::InternalServerError.new("Auth backend is disabled")
    end

    @request = request
  end

  def authorize_resource(*_args)
    raise ExceptionHandler::Unauthorized
  end
end
