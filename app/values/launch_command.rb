class LaunchCommand
  def initialize(str)
    @command = str
  end

  def to_command
    if @command.blank?
      nil
    else
      ["sh", "-c", @command]
    end
  end
end
