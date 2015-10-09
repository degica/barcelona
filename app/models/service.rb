class Service < ActiveRecord::Base
  extend Memoist

  belongs_to :heritage
  has_many :port_mappings, dependent: :destroy

  serialize :command

  validates :name, presence: true
  validates :cpu, numericality: {greater_than: 0}
  validates :memory, numericality: {greater_than: 0}

  accepts_nested_attributes_for :port_mappings

  after_initialize do |service|
    service.cpu ||= 512
    service.memory ||= 512
  end

  after_destroy :delete_service

  def district
    heritage.district
  end

  def apply_to_ecs(image_path)
    register_task(image_path)
    apply_service
  end

  def scale(desired_count)
    ecs.update_service(cluster: district.name,
                       service: service_name,
                       desired_count: desired_count)
  end

  def service_name
    "#{heritage.name}-#{name}"
  end

  def register_task(image_path)
    ecs.register_task_definition(family: service_name,
                                 container_definitions: [container_definition(image_path)])
  end

  def apply_service
    if applied?
      ecs.update_service(
        cluster: district.name,
        service: service_name,
        task_definition: service_name
      )
    else
      params = {
        cluster: district.name,
        service_name: service_name,
        task_definition: service_name,
        desired_count: 1
      }
      if (lbs = load_balancers).present?
        params[:load_balancers] = lbs
        params[:role] = district.ecs_service_role
      end
      ecs.create_service(params)
    end
  end

  def applied?
    !(ecs_service.nil? || ecs_service.status != "ACTIVE")
  end

  def load_balancers
    return [] if port_mappings.blank?
    lb = fetch_load_balancer
    create_load_balancer if lb.nil?
    port_mappings.map do |port_mapping|
      {
        load_balancer_name: service_name,
        container_name: service_name,
        container_port: port_mapping.container_port
      }
    end
  end

  def fetch_load_balancer
    begin
      return @fetched_load_balancer ||= elb.describe_load_balancers(
        load_balancer_names: [service_name],
      ).load_balancer_descriptions.first
    rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
      return nil
    end
  end

  def create_load_balancer
    subnets = district.subnets(public? ? 'Public' : 'Private')
    security_group = public? ? district.public_elb_security_group : district.private_elb_security_group
    load_balancer = elb.create_load_balancer(
      load_balancer_name: service_name,
      subnets: subnets.map(&:subnet_id),
      scheme: public? ? 'internet-facing' : 'internal',
      security_groups: [security_group],
      listeners: port_mappings.map { |port_mapping|
        {
          protocol: "TCP",
          load_balancer_port: port_mapping.lb_port,
          instance_protocol: "TCP",
          instance_port: port_mapping.host_port
        }
      }
    )
    elb.configure_health_check(
      load_balancer_name: service_name,
      health_check: {
        target: "TCP:#{port_mappings.first.host_port}",
        interval: 5,
        timeout: 4,
        unhealthy_threshold: 2,
        healthy_threshold: 2
      }
    )
    elb.modify_load_balancer_attributes(
      load_balancer_name: service_name,
      load_balancer_attributes: {
        connection_draining: {
          enabled: true,
          timeout: 300
        }
      }
    )
    change_elb_record_set("CREATE", load_balancer.dns_name)
  end

  def container_definition(image_path)
    {
      name: service_name,
      cpu: cpu,
      memory: memory,
      essential: true,
      image: image_path,
      command: command,
      port_mappings: port_mappings.map{ |m|
        {
          container_port: m.container_port,
          host_port: m.host_port
        }
      },
      environment: heritage.env_vars.map { |e| {name: e.key, value: e.value} },
      log_configuration: {
        log_driver: "syslog",
        options: {
          "syslog-address" => "tcp://127.0.0.1:514",
          "syslog-tag" => name
        }
      }
    }.compact
  end

  def delete_service
    return unless applied?
    scale(0)
    dns_name = fetch_load_balancer.dns_name
    lb_names = ecs_service.load_balancers.map(&:load_balancer_name)

    ecs.delete_service(cluster: district.name, service: service_name)
    lb_names.each do |name|
      elb.delete_load_balancer(load_balancer_name: name)
    end
    change_elb_record_set("DELETE", dns_name)
  end

  def change_elb_record_set(action, elb_dns_name)
    route53.change_resource_record_sets(
      hosted_zone_id: district.private_hosted_zone_id,
      change_batch: {
        changes: [
          {
            action: action,
            resource_record_set: {
              name: [name, heritage.name, "barcelona.local."].join("."),
              type: "CNAME",
              ttl: 300,
              resource_records: [
                {
                  value: elb_dns_name
                }
              ]
            }
          }
        ]
      }
    )
  end

  def ecs_service
    @ecs_service ||= fetch_ecs_service
  end

  def fetch_ecs_service
    @ecs_service = ecs.describe_services(cluster: district.name, services: [service_name]).services.first
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

  def ecs
    Aws::ECS::Client.new
  end

  def elb
    Aws::ElasticLoadBalancing::Client.new
  end

  def route53
    Aws::Route53::Client.new
  end

  memoize :ecs, :elb, :route53, :load_balancers
end
