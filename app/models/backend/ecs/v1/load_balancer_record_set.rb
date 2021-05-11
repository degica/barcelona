module Backend::Ecs::V1
  class LoadBalancerRecordSet
    attr_accessor :service
    delegate :name, :heritage, :service_name, :district, to: :service
    delegate :aws, to: :district

    def initialize(service)
      @service = service
    end

    def create(load_balancer)
      change_record_set("CREATE", load_balancer.dns_name)
    end

    def delete(load_balancer)
      change_record_set("DELETE", load_balancer.dns_name) if record_set_exist?
    end

    private

    def record_set_exist?
      record = aws.route53.list_resource_record_sets(
        hosted_zone_id: district.private_hosted_zone_id,
        start_record_name: service_record_set_name
      ).resource_record_sets.first
      record.present? && record.name == service_record_set_name.to_s
    end

    def change_record_set(action, elb_dns_name)
      aws.route53.change_resource_record_sets(
        hosted_zone_id: district.private_hosted_zone_id,
        change_batch: {
          changes: [
            {
              action: action,
              resource_record_set: {
                name: service_record_set_name,
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

    def hosted_zone
      @hosted_zone ||= aws.route53.get_hosted_zone(id: district.private_hosted_zone_id).hosted_zone
    end

    def service_record_set_name
      @service_record_set_name ||= [name, heritage.name, hosted_zone.name].join(".")
    end
  end
end
