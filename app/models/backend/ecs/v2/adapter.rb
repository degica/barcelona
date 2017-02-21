module Backend::Ecs::V2
  class Adapter
    attr_accessor :service
    delegate :scale, :status, :desired_count, :running_count, :pending_count, to: :ecs_service, allow_nil: true

    def initialize(service)
      @service = service
    end

    def apply
      std = HeritageTaskDefinition.service_definition(service).to_task_definition
      resp = aws.ecs.register_task_definition(std).task_definition
      td = "#{resp.family}:#{resp.revision}"
      # CloudFormation updates service's desired_count to the declarated value
      # even if application auto scaling is enabled so updating desired count
      # via CloudFormation temporalily breaks the auto scaling behaviour
      # Because of the above here we set the current desired count to
      # the CF template
      desired_count = ecs_service&.desired_count || 0
      cf_executor(td, desired_count).create_or_update

      # For backward-compatibility this method need to return Hash
      {}
    end

    def delete
      cf_executor.delete
    end

    def endpoint
      nil
    end

    def deployment_finished?(_)
      !cf_executor.in_progress?
    end

    private

    def aws
      @aws ||= service.district.aws
    end

    def cf_executor(task_definition = nil, desired_count = nil)
      service_stack = ServiceStack.new(service, task_definition, desired_count)
      CloudFormation::Executor.new(service_stack, aws.cloudformation)
    end

    def ecs_service
      @ecs_service ||= begin
                         executor = cf_executor
                         if executor.stack_status.nil?
                           nil
                         else
                           rid = executor.resource_ids["ECSService"]
                           aws.ecs.describe_services(
                             cluster: service.district.name,
                             services: [rid]
                           ).services.first
                         end
                       end
    end
  end
end
