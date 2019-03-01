class Environment < ApplicationRecord
  belongs_to :heritage
  delegate :district, to: :heritage

  scope :plains, -> { where(value_from: nil) }
  scope :secrets, -> { where.not(value_from: nil) }

  validates :name, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, if: -> { value_from.blank? }
  validates :value_from, presence: true, if: -> { value.blank? }

  attr_accessor :ssm_path

  before_validation do
    if ssm_path
      s = "/" + ssm_path unless ssm_path.start_with?("/")
      s = "/barcelona/#{district.name}" + s unless s.start_with?("/barcelona/#{district.name}")
      self.value_from = s
    end
  end
end
