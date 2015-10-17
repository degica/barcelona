require 'rails_helper'

describe Service do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }

  it { expect{service.save}.to_not raise_error }

  describe "#apply_to_ecs" do
    let(:ecs_mock) { double }
    context "when updating service" do
      before do
        allow(service).to receive(:applied?) { true }
        allow(service).to receive(:ecs) { ecs_mock }
      end

      context "when port_mappings is blank" do
        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [service.container_definition]
                               )
          expect(ecs_mock).to receive(:update_service)
                               .with(
                                 cluster: service.district.name,
                                 service: service.service_name,
                                 task_definition: service.service_name
                               )
          expect{service.apply_to_ecs}.to_not raise_error
        end
      end
    end

    context "when creating service" do
      before do
        allow(service).to receive(:applied?) { false }
        allow(service).to receive(:ecs) { ecs_mock }
      end

      context "when port_mappings is blank" do
        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [service.container_definition]
                               )
          expect(ecs_mock).to receive(:create_service)
                               .with(
                                 cluster: service.district.name,
                                 service_name: service.service_name,
                                 task_definition: service.service_name,
                                 desired_count: 1
                               )
          expect{service.apply_to_ecs}.to_not raise_error
        end
      end

      context "when port_mappings is present" do
        let(:elb_mock) { double }
        let(:route53_mock) { double }

        before do
          allow(service).to receive(:elb) { elb_mock }
          allow(service).to receive(:route53) { route53_mock }
          allow(service).to receive(:fetch_load_balancer) { nil }
          service.port_mappings.create(lb_port: 80, container_port: 3000)
        end

        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [service.container_definition]
                               )
          expect(ecs_mock).to receive(:create_service)
                               .with(
                                 cluster: service.district.name,
                                 service_name: service.service_name,
                                 task_definition: service.service_name,
                                 load_balancers: [
                                   {
                                     load_balancer_name: "awesome-app-web",
                                     container_name: 'awesome-app-web',
                                     container_port: 3000
                                   }
                                 ],
                                 role: service.district.ecs_service_role,
                                 desired_count: 1
                               )
          expect(elb_mock).to receive(:create_load_balancer)
                               .with(
                                 load_balancer_name: 'awesome-app-web',
                                 subnets: [],
                                 scheme: 'internet-facing',
                                 security_groups: [service.district.public_elb_security_group],
                                 listeners: [
                                   protocol: 'TCP',
                                   load_balancer_port: 80,
                                   instance_protocol: 'TCP',
                                   instance_port: service.port_mappings.first.host_port
                                 ]
                               )
                               .and_return(OpenStruct.new(dns_name: 'dns.internal'))
          expect(elb_mock).to receive(:configure_health_check)
                               .with(
                                 load_balancer_name: 'awesome-app-web',
                                 health_check: {
                                   target: "TCP:#{service.port_mappings.first.host_port}",
                                   interval: 5,
                                   timeout: 4,
                                   unhealthy_threshold: 2,
                                   healthy_threshold: 2
                                 }
                               )
          expect(elb_mock).to receive(:modify_load_balancer_attributes)
                               .with(
                                 load_balancer_name: 'awesome-app-web',
                                 load_balancer_attributes: {
                                   connection_draining: {
                                     enabled: true,
                                     timeout: 300
                                   }
                                 }
                               )
          expect(route53_mock).to receive(:change_resource_record_sets)
                                   .with(
                                     hosted_zone_id: service.district.private_hosted_zone_id,
                                     change_batch: {
                                       changes: [
                                         {
                                           action: "CREATE",
                                           resource_record_set: {
                                             name: "web.awesome-app.barcelona.local.",
                                             type: "CNAME",
                                             ttl: 300,
                                             resource_records: [
                                               {
                                                 value: 'dns.internal'
                                               }
                                             ]
                                           }
                                         }
                                       ]
                                     }
                                   )
          expect{service.apply_to_ecs}.to_not raise_error
        end
      end
    end
  end

  describe "#delete_service" do
    let(:ecs_mock) { double }
    let(:route53_mock) { double }

    before do
      allow(service).to receive(:applied?) { true }
      allow(service).to receive(:ecs) { ecs_mock }
      allow(service).to receive(:route53) { route53_mock }
    end

    it "deltes ECS resources" do
      expect(ecs_mock).to receive(:update_service)
                           .with(
                             cluster: service.district.name,
                             service: service.service_name,
                             desired_count: 0
                           )
      expect(service).to receive(:fetch_load_balancer) do
        OpenStruct.new(load_balancer_name: 'awesome-app-web', dns_name: 'dns.elb')
      end

      expect(ecs_mock).to receive(:delete_service)
                           .with(
                             cluster: service.district.name,
                             service: service.service_name
                           )
      expect(route53_mock).to receive(:change_resource_record_sets)
                               .with(
                                 hosted_zone_id: service.district.private_hosted_zone_id,
                                 change_batch: {
                                   changes: [
                                     {
                                       action: "DELETE",
                                       resource_record_set: {
                                         name: "web.awesome-app.barcelona.local.",
                                         type: "CNAME",
                                         ttl: 300,
                                         resource_records: [
                                           {
                                             value: 'dns.elb'
                                           }
                                         ]
                                       }
                                     }
                                   ]
                                 }
                               )
      expect{service.delete_service}.to_not raise_error
    end
  end
end
