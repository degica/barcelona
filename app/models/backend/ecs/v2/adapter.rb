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
      # CloudFormation updates service's desired_count to the declarated value
      # even if application auto scaling is enabled so updating desired count
      # via CloudFormation temporalily breaks the auto scaling behaviour
      # Because of the above here we set the current desired count to
      # the CF template
      service_stack.task_definition = "#{resp.family}:#{resp.revision}"
      service_stack.desired_count = service.desired_container_count || ecs_service&.desired_count || 1
      cf_executor.create_or_update

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

    def rid
      10.times do |try_num|
        result = cf_executor.resource_ids["ECSService"]
        return result unless result.nil?
        puts "Failed to retrieve resource id for service #{service.service_name}. Retrying. Try number: #{try_num}"
        sleep 10
      rescue => e
        puts "Encountered error while retrieving resource id: #{e.message}"
      end
    end

    private

    def aws
      @aws ||= service.district.aws
    end

    def service_stack
      @service_stack ||= ServiceStack.new(service)
    end

    def cf_executor
      @cf_executor ||= CloudFormation::Executor.new(service_stack, service.district)
    end

    def ecs_service
      @ecs_service ||= begin
                         executor = cf_executor
                         if executor.stack_status.nil?
                           nil
                         else
                           puts "Extracting service info for #{service.service_name}. Status: #{executor.stack_status}"
                           aws.ecs.describe_services(
                             cluster: service.district.name,
                             services: [rid]
                           ).services.first
                         end
                       end
    end
  end
end
