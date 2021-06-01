class Notification < ApplicationRecord
  belongs_to :district, inverse_of: :notifications

  validates :target, presence: true, inclusion: {in: %w[slack]}
  validates :endpoint, format: { with: %r{\Ahttps://hooks\.slack\.com/services/} }, if: proc { |n| n.target == "slack" }
end
