module Backend::Ecs::V1
  class Elb
    attr_accessor :service

    delegate :port_mappings, :service_name, :district, :public?, to: :service
    delegate :aws, to: :district

    def initialize(service)
      @service = service
    end

    def fetch_load_balancer
      return @fetched_load_balancer ||= aws.elb.describe_load_balancers(
        load_balancer_names: [service_name]
      ).load_balancer_descriptions.first
    rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
      return nil
    end

    def create
      load_balancer = fetch_load_balancer
      return load_balancer if load_balancer.present?
      return nil if port_mappings.blank?

      load_balancer = create_load_balancer
      configure_health_check
      configure_proxy_protocol

      OpenStruct.new(load_balancer_name: service_name, dns_name: load_balancer.dns_name)
    end

    def exist?
      fetch_load_balancer.present?
    end

    def update
      load_balancer = fetch_load_balancer
      raise "ELB not created" if load_balancer.nil?

      configure_health_check

      OpenStruct.new(load_balancer_name: service_name, dns_name: load_balancer.dns_name)
    end

    def delete
      lb = fetch_load_balancer
      aws.elb.delete_load_balancer(load_balancer_name: lb.load_balancer_name) if lb.present?
      lb
    end

    def health_check_target
      health_check = service.health_check
      protocol = health_check["protocol"] || "tcp"
      case protocol
      when "tcp" then
        port = health_check["port"] || service.port_mappings.first.host_port
        "TCP:#{port}"
      when "http" then
        http_path = health_check["http_path"]
        port = health_check["port"] || service.http_port_mapping.host_port
        "#{protocol.upcase}:#{port}#{http_path}"
      when "https" then
        http_path = health_check["http_path"]
        port = health_check["port"] || service.https_port_mapping.host_port
        "#{protocol.upcase}:#{port}#{http_path}"
      end
    end

    private

    def create_load_balancer
      subnets = district.subnets(public? ? 'Public' : 'Private')
      security_group = public? ? district.public_elb_security_group : district.private_elb_security_group
      load_balancer = aws.elb.create_load_balancer(
        load_balancer_name: service_name,
        subnets: subnets.map(&:subnet_id),
        scheme: public? ? 'internet-facing' : 'internal',
        security_groups: [security_group],
        listeners: port_mappings.lb_registerable.map do |pm|
          {
            protocol: "TCP",
            load_balancer_port: pm.lb_port,
            instance_protocol: "TCP",
            instance_port: pm.host_port
          }
        end
      )
      aws.elb.modify_load_balancer_attributes(
        load_balancer_name: service_name,
        load_balancer_attributes: {
          cross_zone_load_balancing: {
            enabled: true
          },
          connection_draining: {
            enabled: true,
            timeout: 60
          }
        }
      )
      load_balancer
    end

    def configure_health_check
      aws.elb.configure_health_check(
        load_balancer_name: service_name,
        health_check: {
          target: health_check_target,
          interval: 5,
          timeout: 4,
          unhealthy_threshold: 2,
          healthy_threshold: 2
        }
      )
    end

    def configure_proxy_protocol
      # Enable ProxyProtocol for http/https host ports
      ports = port_mappings.where(protocol: %w(http https)).pluck(:host_port)
      ports += port_mappings.where(enable_proxy_protocol: true).pluck(:host_port)
      if ports.present?
        aws.elb.create_load_balancer_policy(
          load_balancer_name: service_name,
          policy_name: "#{service_name}-ProxyProtocol",
          policy_type_name: "ProxyProtocolPolicyType",
          policy_attributes: [
            {
              attribute_name: 'ProxyProtocol',
              attribute_value: 'true'
            }
          ]
        )
        ports.uniq.each do |port|
          aws.elb.set_load_balancer_policies_for_backend_server(
            load_balancer_name: service_name,
            instance_port: port,
            policy_names: ["#{service_name}-ProxyProtocol"]
          )
        end
      end
    end
  end
end
