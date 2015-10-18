module Backend::Ecs
  class LoadBalancerRecordSet
    include AwsAccessible

    attr_accessor :service
    delegate :name, :heritage, :service_name, :district, to: :service

    def initialize(service)
      @service = service
    end

    def create(load_balancer)
      change_record_set("CREATE", load_balancer.dns_name)
    end

    def delete(load_balancer)
      change_record_set("DELETE", load_balancer.dns_name)
    end

    private

    def change_record_set(action, elb_dns_name)
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
  end
end
