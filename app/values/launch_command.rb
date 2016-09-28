class LaunchCommand
  attr_accessor :heritage, :command

  def initialize(heritage, command)
    @heritage = heritage
    @command = command
  end

  def to_command
    [
      "sh", "-c",
      [
        "exec",
        "/barcelona/barcelona-run",
        "load-env-and-run",
        "--region #{heritage.district.region}",
        "--bucket-name #{heritage.district.s3_bucket_name}",
        heritage.env_vars.where(secret: true).map { |e| "-e #{e.key}=#{e.s3_path}" },
        @command
      ].flatten.join(" ")
    ]
  end
end
