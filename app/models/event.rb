class Event < ActiveRecord::Base
  belongs_to :app

  validates :uuid, uniqueness: true, presence: true
  validates :app, presence: true
  validates :level, inclusion: { in: %w(good warn error)}

  after_initialize :set_uuid
  before_validation :set_level
  after_create :send_notifications

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def set_level
    self.level ||= "good"
    self.level = self.level.to_s
  end

  def send_notifications
    Rails.logger.info(user_message)
    return if app.slack_url.blank?
    notifier = Slack::Notifier.new(app.slack_url, username: "Barcelona")
    notifier.ping("", attachments: [{color: slack_color, text: user_message}])
  end

  def slack_color
    { "good"  => "good",
      "warn"  => "warning",
      "error" => "danger" }[level]
  end

  def user_message
    "[#{app.name}] #{message}"
  end
end
