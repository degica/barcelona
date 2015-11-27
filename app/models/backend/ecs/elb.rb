module Backend::Ecs
  class Elb
    attr_accessor :service

    delegate :port_mappings, :service_name, :district, :public?, to: :service
    delegate :aws, to: :district

    def initialize(service)
      @service = service
    end

    def fetch_load_balancer
      begin
        return @fetched_load_balancer ||= aws.elb.describe_load_balancers(
          load_balancer_names: [service_name],
        ).load_balancer_descriptions.first
      rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
        return nil
      end
    end

    def create
      load_balancer = fetch_load_balancer
      return load_balancer if load_balancer.present?
      return nil if port_mappings.blank?

      subnets = district.subnets(public? ? 'Public' : 'Private')
      security_group = public? ? district.public_elb_security_group : district.private_elb_security_group
      load_balancer = aws.elb.create_load_balancer(
        load_balancer_name: service_name,
        subnets: subnets.map(&:subnet_id),
        scheme: public? ? 'internet-facing' : 'internal',
        security_groups: [security_group],
        listeners: port_mappings.lb_registerable.map { |pm|
          {
            protocol: "TCP",
            load_balancer_port: pm.lb_port,
            instance_protocol: "TCP",
            instance_port: pm.host_port
          }
        }
      )
      aws.elb.configure_health_check(
        load_balancer_name: service_name,
        health_check: {
          target: "TCP:#{port_mappings.first.host_port}",
          interval: 5,
          timeout: 4,
          unhealthy_threshold: 2,
          healthy_threshold: 2
        }
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
      OpenStruct.new(load_balancer_name: service_name, dns_name: load_balancer.dns_name)
    end

    def delete
      lb = fetch_load_balancer
      aws.elb.delete_load_balancer(load_balancer_name: lb.load_balancer_name) if lb.present?
      lb
    end
  end
end
