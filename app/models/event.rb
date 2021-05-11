class Event
  def initialize(district = nil)
    @district = district

    # Try finding an appropriate district to notify
    # First try to find a district where Barcelona itself is running
    # If not found (e.g. Barcelona is running locally or on heroku)
    # try finding "default" district
    @district ||= Heritage.find_by(name: 'barcelona')&.district
    @district ||= District.find_by(name: 'default')
  end

  def notify(message:, level: :good)
    return if @district.nil?

    Rails.logger.info(message)
    @district.publish_sns(message, level: slack_color(level))
  end

  def slack_color(level)
    { "good" => "good",
      "warn" => "warning",
      "error" => "danger" }[level.to_s]
  end
end
