class SsmParameters
  def initialize(district, name)
    @district = district
    @name = name
  end

  def put_parameter(value)
    client.put_parameter({
                           name: ssm_path, # required
                           value: value, # required
                           type: "SecureString",
                           overwrite: true
                         })
  end

  def delete_parameter
    client.delete_parameters({
                               names: [ssm_path]
                             })
  end

  def get_invalid_parameters(ssm_paths)
    return [] if ssm_paths.empty?

    if ssm_paths.length > 10
      raise ExceptionHandler::UnprocessableEntity.new("Failed to get ssm parameters: length should be less than 10 #{ssm_paths}")
    end

    response = client.get_parameters({
                                       names: ssm_paths
                                     })
    response.invalid_parameters
  rescue StandardError => e
    raise ExceptionHandler::UnprocessableEntity.new("Failed to get ssm parameters: #{e}")
  end

  def ssm_path
    "/barcelona/#{@district.name}/#{@name}"
  end

  private

  def client
    @client ||= @district.aws.ssm
  end
end
