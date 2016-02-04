module Backend::Ecs
  class Adapter
    attr_accessor :service

    delegate :scale, :status, :desired_count, :running_count, :pending_count, to: :ecs_service

    def initialize(service)
      @service = service
    end

    def apply
      ecs_service.register_task
      if ecs_service.applied?
        ecs_service.update
        elb.update if elb.exist?
      else
        load_balancer = elb.create
        record_set.create(load_balancer) if load_balancer.present?
        ecs_service.create(load_balancer)
      end
    end

    def delete
      ecs_service.delete
      load_balancer = elb.delete
      record_set.delete(load_balancer) if load_balancer.present?
    end

    def endpoint
      lb = elb.fetch_load_balancer
      if lb.nil?
        nil
      else
        {
          name: lb.load_balancer_name,
          dns_name: lb.dns_name
        }
      end
    end

    def ecs_service
      @ecs_service ||= Backend::Ecs::Service.new(service)
    end

    def elb
      @elb ||= Backend::Ecs::Elb.new(service)
    end

    def record_set
      @record_set ||= Backend::Ecs::LoadBalancerRecordSet.new(service)
    end
  end
end
