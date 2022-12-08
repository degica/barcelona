class ServiceDeployment < ApplicationRecord
  belongs_to :service

  validates :service, presence: true
  validate :finished_cannot_both_be_true

  def finished_cannot_both_be_true
    if completed_at.present? && failed_at.present?
      errors.add(:completed_at, "can't be true with failed_at")
    end
  end

  scope :unfinished, -> { where('completed_at is null and failed_at is null') }

  def finished?
    completed? || failed?
  end

  def completed?
    !completed_at.nil?
  end

  def failed?
    !failed_at.nil?
  end

  def complete!
    self.completed_at = Time.now
    self.save!
  end

  def fail!
    self.failed_at = Time.now
    self.save!
  end

end
