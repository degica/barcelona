class SsmParameters
  PARAMETER_TYPES = %w[String StringList SecureString].freeze

  def initialize(district, name)
    @district = district
    @name = name
  end

  def put_parameter(value, type)
    unless PARAMETER_TYPES.include?(type)
      raise ExceptionHandler::InternalServerError.new("Type #{type} is not in #{PARAMETER_TYPES}")
    end

    client.put_parameter({
                           name: ssm_path, # required
                           value: value, # required
                           type: type # accepts String, StringList, SecureString
                         })
  end

  def ssm_path
    "/barcelona/#{@district.name}/#{@name}"
  end

  private

  def client
    @client ||= @district.aws.ssm
  end
end
