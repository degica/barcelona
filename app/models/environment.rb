class Environment < ApplicationRecord
  belongs_to :heritage
  delegate :district, to: :heritage

  scope :plains, -> { where(value_from: nil) }
  scope :secrets, -> { where.not(value_from: nil) }

  validates :name, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, if: -> { value_from.blank? }
  validates :value_from, presence: true, if: -> { value.blank? }


  # If value_from is nil return it as-is
  # if value_from is a relative name prefix /barcelona/district-name/
  #   ECS resolves relative value_from as a SSM parameter in the same account and region
  def namespaced_value_from
    return nil if value_from.nil?
    return value_from if value_from.start_with?("arn:aws:")

    s = value_from
    s = "/" + s unless s.start_with?("/")
    s = "/barcelona/#{district.name}" + s unless s.start_with?("/barcelona/#{district.name}")
    s
  end
end
