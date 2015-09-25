class ExceptionHandler
  class Exception < StandardError
    attr_accessor :errors

    def initialize(errors = [])
      super
      @errors = errors
    end

    def to_rack_response(debug=false)
      [status_code, headers, [body(debug)]]
    end

    def status_code
      500
    end

    def headers
      { "Content-Type" => "application/json" }
    end

    def body(debug)
      data = { errors: errors.presence || [default_error] }
      if debug
        data.merge!(
          backtrace: original.backtrace,
          debug_message: original.message
        )
      end
      data.to_json
    end

    private

    def original
      cause || self
    end

    def error_type
      self.class.to_s.split("::").last.underscore
    end

    def default_error
      {
        type: error_type
      }
    end
  end

  class InternalServerError < Exception
  end

  class NotFound < Exception
    def status_code
      404
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue ActiveRecord::RecordNotFound
      raise NotFound
    rescue
      raise InternalServerError
    end
  rescue ExceptionHandler::Exception => e
    debug = Rails.env.development?
    e.to_rack_response(debug)
  end
end
