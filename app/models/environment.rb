class Environment < ApplicationRecord
  belongs_to :heritage
  delegate :district, to: :heritage

  scope :plains, -> { where(value_from: nil) }
  scope :secrets, -> { where.not(value_from: nil) }

  validates :name, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, if: -> { value_from.blank? }
  validates :value_from, presence: true, if: -> { value.blank? }

  attr_reader :ssm_path

  def ssm_path=(val)
    attribute_will_change!(:value_from)
    @ssm_path = val
  end

  before_validation do
    if ssm_path
      s = ssm_path
      s = "/" + ssm_path unless ssm_path.start_with?("/")
      s = "/barcelona/#{district.name}" + s unless s.start_with?("/barcelona/#{district.name}")
      self.value_from = s
    end
  end

  before_validation :cleanup_old_value

  # value and value_from are exlusive. Only one of those can be non-null
  def cleanup_old_value
    if will_save_change_to_attribute?(:value) && !value.nil?
      self.value_from = nil
    end

    if will_save_change_to_attribute?(:value_from) && !value_from.nil?
      self.value = nil
    end
  end
end
