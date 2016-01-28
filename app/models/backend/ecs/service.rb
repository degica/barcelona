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

    def container_definition
      base = service.heritage.base_task_definition(service_name)
      base[:environment] += service.port_mappings.map do |pm|
        {
          name: "HOST_PORT_#{pm.protocol.upcase}_#{pm.container_port}",
          value: pm.host_port.to_s
        }
      end
      if service.web?
        base[:environment] << {
          name: "PORT",
          value: service.web_container_port.to_s
        }
      end

      base.merge(
        cpu: cpu,
        memory: memory,
        command: LaunchCommand.new(command).to_command,
        port_mappings: port_mappings.to_task_definition
      ).compact
    end

    def reverse_proxy_definition
      base = service.heritage.base_task_definition("#{service.service_name}-revpro")
      base[:environment] += [
        {name: "AWS_REGION", value: 'ap-northeast-1'},
        {name: "UPSTREAM_NAME", value: "backend"},
        {name: "UPSTREAM_PORT", value: service.web_container_port.to_s},
        {name: "FORCE_SSL", value: (!!service.force_ssl).to_s},
        service.hosts.map do |h|
          host_key = h['hostname'].tr('.', '_').gsub('-', '__').upcase
          [
            {name: "CERT_#{host_key}", value: h['ssl_cert_path']},
            {name: "KEY_#{host_key}", value: h['ssl_key_path']}
          ]
        end
      ].flatten

      http_hosts = service.hosts.map{ |h| h['hostname'] }.join(',')
      base[:environment] << {name: "HTTP_HOSTS", value: http_hosts} if http_hosts.present?

      http = service.port_mappings.http
      https = service.port_mappings.https
      base.merge(
        cpu: 128,
        memory: 128,
        image: service.reverse_proxy_image,
        links: ["#{service.service_name}:backend"],
        port_mappings: [
          {
            container_port: 80,
            host_port: http.host_port,
            protocol: "tcp"
          },
          {
            container_port: 443,
            host_port: https.host_port,
            protocol: "tcp"
          }
        ]
      )
    end

    def container_definitions
      definitions = [container_definition]
      definitions << reverse_proxy_definition if service.web?
      definitions
    end

    def applied?
      !(ecs_service.nil? || ecs_service.status != "ACTIVE")
    end

    def register_task
      aws.ecs.register_task_definition(family: service.service_name,
                                       container_definitions: container_definitions)
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
