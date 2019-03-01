class LaunchCommand
  attr_accessor :heritage, :command, :options

  def initialize(heritage, command, options = {shell_format: true})
    @heritage = heritage
    @command = command
    @options = options
  end

  def to_command
    if options[:shell_format]
      ["sh", "-c", "exec #{arguments.join(' ')}"]
    else
      arguments
    end
  end

  def arguments
    [
      "/barcelona/barcelona-run",
      "load-env-and-run",
      "--region", heritage.district.region,
      "--bucket-name", heritage.district.s3_bucket_name,
      heritage.legacy_secrets.map { |e| ["-e", "#{e.key}=#{e.s3_path}"] },
      @command
    ].flatten
  end
end
