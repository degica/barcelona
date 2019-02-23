class Environment < ApplicationRecord
  belongs_to :heritage
  delegate :district, to: :heritage

  scope :plains, -> { where(value_from: nil) }
  scope :secrets, -> { where.not(value_from: nil) }

  validates :name, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, if: -> { value_from.blank? }
  validates :value_from, presence: true, if: -> { value.blank? }

  def namespaced_value_from
    s = value_from
    s = "/" + s unless s.start_with?("/")
    s = "/barcelona/#{district.name}" + s unless s.start_with?("/barcelona/#{district.name}")
    s
  end
end
