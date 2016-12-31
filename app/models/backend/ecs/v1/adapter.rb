module Backend::Ecs::V1
  class Adapter
    Result = Struct.new(:task_definition, :deployment_id)

    attr_accessor :service

    delegate :scale, :status, :desired_count, :running_count, :pending_count, to: :ecs_service

    def initialize(service)
      @service = service
    end

    def apply
      ecs_service.register_task
      if ecs_service.applied?
        service_res = ecs_service.update
        elb.update if elb.exist?
      else
        load_balancer = elb.create
        record_set.create(load_balancer) if load_balancer.present?
        service_res = ecs_service.create(load_balancer)
      end

      Result.new(
        service_res.service.task_definition.split('/').last,
        service_res.service.deployments.first.id
      )
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

    def deployment_status(deployment_id)
      deployment = ecs_service.deployment(deployment_id)
      # deployment being nil means the deployment finished and
      # another newer deployment takes in place as PRIMARY
      # http://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Deployment.html
      return :complete if deployment.nil? || deployment.status == "INACTIVE"

      # A deployment is considered as finished when
      # 1) There is only one PRIMARY deployment, and
      # 2) The number of running tasks deployed by PRIMARY deployment
      #    reaches to service's desired task count
      if ecs_service.deployments.count == 1 && deployment.status == "PRIMARY" && deployment.desired_count == deployment.running_count
        :complete
      else
        :in_progress
      end
    end

    def ecs_service
      @ecs_service ||= Backend::Ecs::V1::Service.new(service)
    end

    def elb
      @elb ||= Backend::Ecs::V1::Elb.new(service)
    end

    def record_set
      @record_set ||= Backend::Ecs::V1::LoadBalancerRecordSet.new(service)
    end
  end
end
