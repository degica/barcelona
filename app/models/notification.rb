class Notification < ApplicationRecord
  belongs_to :district, inverse_of: :notifications

  validates :target, presence: true, inclusion: {in: %w(slack)}
  validate :validate_endpoint

  def validate_endpoint
    case target
    when "slack"
      unless endpoint =~ %r{^https://hooks\.slack\.com/services/}
        errors.add(:notifications, "slack endpoint is invalid")
      end
    end
  end
end
