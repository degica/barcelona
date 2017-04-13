class Listener < ActiveRecord::Base
  belongs_to :endpoint, required: true, inverse_of: :listeners
  belongs_to :service, required: true, inverse_of: :listeners
  validates :endpoint_id, uniqueness: {scope: :service_id}
  validates :health_check_interval,
            numericality: {greater_than_or_equal_to: 5, less_than_or_equal_to: 300}
  validates :health_check_timeout,
            numericality: {greater_than_or_equal_to: 5, less_than_or_equal_to: 60}
  validates :healthy_threshold_count,
            numericality: {greater_than_or_equal_to: 2, less_than_or_equal_to: 10}
  validates :unhealthy_threshold_count,
            numericality: {greater_than_or_equal_to: 2, less_than_or_equal_to: 10}
  validate :timeout_must_be_less_than_interval

  serialize :rule_conditions, JsonWithIndifferentAccess

  before_validation do |lis|
    lis.health_check_interval ||= 10
    lis.health_check_path ||= '/'
    lis.health_check_timeout ||= 5
    lis.healthy_threshold_count ||= 2
    lis.unhealthy_threshold_count ||= 2
    lis.rule_conditions ||= [{type: "path-pattern", value: "*"}]
    lis.rule_priority ||= 100
  end

  def timeout_must_be_less_than_interval
    if health_check_timeout >= health_check_interval
      errors.add(:health_check_timeout, "must be less than health_check_interval")
    end
  end
end
