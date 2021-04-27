class ProcessSsm
  def initialize(district, name)
    @district = district
    @name = name
  end

  def get_parameter
    client.get_parameter({
      name: ssm_path,
      with_decryption: true,
    })
  end

  def ssm_path
    "/barcelona/#{@district.name}/#{@name}"
  end

  private

  def client
    client ||= @district.aws.ssm
  end
end
