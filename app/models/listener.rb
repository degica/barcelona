class Listener < ActiveRecord::Base
  belongs_to :endpoint, required: true, inverse_of: :listeners
  belongs_to :service, required: true, inverse_of: :listeners
  validates :endpoint_id, uniqueness: {scope: :service_id}

  serialize :rule_conditions, JsonWithIndifferentAccess

  after_initialize do |lis|
    lis.health_check_interval ||= 10
    lis.health_check_path ||= '/'
    lis.rule_conditions ||= [{type: "path-pattern", value: "*"}]
    lis.rule_priority ||= 100
  end
end
