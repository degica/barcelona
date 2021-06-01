module Backend::Ecs::V1
  class Service
    attr_accessor :service
    delegate :service_name, :cpu, :memory, :command, :port_mappings, :district, to: :service
    delegate :desired_count, :running_count, :pending_count, to: :ecs_service
    delegate :aws, to: :district

    def initialize(service)
      @service = service
    end

    def scale(desired_count)
      aws.ecs.update_service(cluster: cluster_name,
                             service: service_name,
                             desired_count: desired_count)
    end

    def delete
      return unless applied?

      scale(0)
      aws.ecs.delete_service(cluster: cluster_name, service: service.service_name)
    end

    def status
      return :not_created if ecs_service.nil?

      deployment_statuses = ecs_service.deployments.map(&:status)
      if ecs_service.status != "ACTIVE"
        :inactive
      elsif deployment_statuses.include? "ACTIVE"
        :deploying
      elsif deployment_statuses == ["PRIMARY"]
        :active
      else
        :unknown
      end
    end

    def desired_count
      ecs_service&.desired_count
    end

    def running_count
      ecs_service&.running_count
    end

    def pending_count
      ecs_service&.pending_count
    end

    def deployment(id)
      return nil if deployments.nil?

      deployments.find { |d| d.id == id }
    end

    def deployments
      ecs_service&.deployments
    end

    def applied?
      !(ecs_service.nil? || ecs_service.status != "ACTIVE")
    end

    def register_task
      task_definition = HeritageTaskDefinition.service_definition(service).to_task_definition
      aws.ecs.register_task_definition(task_definition)
    end

    def update
      aws.ecs.update_service(
        cluster: cluster_name,
        service: service.service_name,
        task_definition: service.service_name
      )
    end

    def create(load_balancer)
      params = {
        cluster: cluster_name,
        service_name: service.service_name,
        task_definition: service.service_name,
        desired_count: 1
      }
      if load_balancer.present?
        # Currently ECS doesn't support assigning multi ELB to a particular ECS service
        # so only the first port mapping is set to ECS service
        # If the service has multiple port mappings it just works because both the ELB and
        # ECS task definition has multiple port settings

        #        params[:load_balancers] = port_mappings.tcp.map do |port_mapping|
        #          {
        #            load_balancer_name: load_balancer.load_balancer_name,
        #            container_name: service_name,
        #            container_port: port_mapping.container_port
        #          }
        #        end
        # FIXME: ugly hack
        container_name = service_name
        port_mapping = port_mappings.lb_registerable.first
        container_port = port_mapping.container_port
        if port_mapping.http? || port_mapping.https?
          container_name = "#{service_name}-revpro"
          container_port = port_mapping.lb_port
        end
        params[:load_balancers] = [
          {
            load_balancer_name: load_balancer.load_balancer_name,
            container_name: container_name,
            container_port: container_port
          }
        ]
        params[:role] = district.ecs_service_role
      end
      aws.ecs.create_service(params)
    end

    def ecs_service
      @ecs_service ||= fetch_ecs_service
    end

    def fetch_ecs_service
      @ecs_service = aws.ecs.describe_services(
        cluster: cluster_name,
        services: [service.service_name]
      ).services.first
    end

    private

    def cluster_name
      district.name
    end
  end
end
