class DeployService

  STATUS_TO_ACTION_MAP = {
                              "CREATE_IN_PROGRESS" => :incomplete,
                                   "CREATE_FAILED" => :failed,
                                 "CREATE_COMPLETE" => :completed,
                            "ROLLBACK_IN_PROGRESS" => :incomplete,
                                 "ROLLBACK_FAILED" => :failed,
                               "ROLLBACK_COMPLETE" => :failed,
                              "DELETE_IN_PROGRESS" => :incomplete,
                                   "DELETE_FAILED" => :failed,
                                 "DELETE_COMPLETE" => :completed,
                              "UPDATE_IN_PROGRESS" => :incomplete,
             "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" => :incomplete,
                                 "UPDATE_COMPLETE" => :completed,
                                   "UPDATE_FAILED" => :failed,
                     "UPDATE_ROLLBACK_IN_PROGRESS" => :failed,
                          "UPDATE_ROLLBACK_FAILED" => :failed,
    "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS" => :failed,
                        "UPDATE_ROLLBACK_COMPLETE" => :failed,
                              "REVIEW_IN_PROGRESS" => :incomplete,
                              "IMPORT_IN_PROGRESS" => :incomplete,
                                 "IMPORT_COMPLETE" => :completed,
                     "IMPORT_ROLLBACK_IN_PROGRESS" => :failed,
                          "IMPORT_ROLLBACK_FAILED" => :failed,
                        "IMPORT_ROLLBACK_COMPLETE" => :failed
  }.freeze

  class << self
    def deploy_service(service)
      ServiceDeployment.create!(service: service)
    end
  end

  def initialize(district)
    @district = district
  end

  def check
    statuses = stack_statuses

    @district.heritages.each do |heritage|
      heritage.services.each do |service|
        next if service.deployment.finished?

        status = statuses[heritage.name]
        action = STATUS_TO_ACTION_MAP[status]
        notify(service, action)
      end
    end
  end

  def notify(service, action)
    send("notify_#{action}", service)
  end

  def notify_completed(service)
  end

  def notify_incomplete(service)
  end

  def notify_failed(service)
  end

  def stack_names
    @stack_names ||= @district.heritages.pluck(:name).map do |x|
      ["heritage-#{x}", x]
    end.to_h
  end

  def stack_statuses
    results = {}

    cloudformation.list_stacks.each do |response|
      response.stack_summaries.each do |summary|
        if stack_names.key?(summary.stack_name)
          results[stack_names[summary.stack_name]] = summary.stack_status
        end
      end
    end

    results
  end

  private

  def cloudformation
    @cloudformation ||= @district.aws.cloudformation
  end

end
