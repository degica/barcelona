module Backend::Ecs
  class Service
    attr_accessor :service
    delegate :service_name, :cpu, :memory, :command, :port_mappings, :district, to: :service
    delegate :desired_count, :running_count, :pending_count, to: :ecs_service
    delegate :aws, to: :district

    def initialize(service)
      @service = service
    end

    def scale(desired_count)
      aws.ecs.update_service(cluster: section.cluster_name,
                             service: service_name,
                             desired_count: desired_count)
    end

    def delete
      return unless applied?
      scale(0)
      aws.ecs.delete_service(cluster: section.cluster_name, service: service.service_name)
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
      ecs_service.try(:desired_count)
    end

    def running_count
      ecs_service.try(:running_count)
    end

    def pending_count
      ecs_service.try(:pending_count)
    end

    def container_definition
      base = service.heritage.base_task_definition(service_name)
      base[:environment] += service.port_mappings.map do |pm|
        {
          name: "HOST_PORT_#{pm.protocol.upcase}_#{pm.container_port}",
          value: pm.host_port.to_s
        }
      end

      base.merge(
        cpu: cpu,
        memory: memory,
        command: command.try(:split, " "),
        port_mappings: port_mappings.map{ |m|
          {
            container_port: m.container_port,
            host_port: m.host_port,
            protocol: m.protocol
          }
        }
      ).compact
    end

    def applied?
      !(ecs_service.nil? || ecs_service.status != "ACTIVE")
    end

    def register_task
      aws.ecs.register_task_definition(family: service.service_name,
                                   container_definitions: [container_definition])
    end

    def update
      aws.ecs.update_service(
        cluster: section.cluster_name,
        service: service.service_name,
        task_definition: service.service_name
      )
    end

    def create(load_balancer)
      params = {
        cluster: section.cluster_name,
        service_name: service.service_name,
        task_definition: service.service_name,
        desired_count: 1
      }
      if load_balancer.present?
        params[:load_balancers] = port_mappings.map do |port_mapping|
          {
            load_balancer_name: load_balancer.load_balancer_name,
            container_name: service_name,
            container_port: port_mapping.container_port
          }
        end
        params[:role] = district.ecs_service_role
      end
      aws.ecs.create_service(params)
    end

    def ecs_service
      @ecs_service ||= fetch_ecs_service
    end

    def fetch_ecs_service
      @ecs_service = aws.ecs.describe_services(
        cluster: section.cluster_name,
        services: [service.service_name]
      ).services.first
    end

    private

    def section
      service.heritage.section
    end
  end
end
