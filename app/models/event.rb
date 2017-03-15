class Event
  def initialize(district)
    @district = district
  end

  def notify(message:, level: :good)
    Rails.logger.info(message)
    @district.publish_sns(message, level: slack_color(level))
  end

  def slack_color(level)
    { "good"  => "good",
      "warn"  => "warning",
      "error" => "danger" }[level.to_s]
  end
end
