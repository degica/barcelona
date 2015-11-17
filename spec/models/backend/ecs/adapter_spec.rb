require 'rails_helper'

describe Backend::Ecs::Adapter do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }
  let(:adapter) { described_class.new(service) }

  describe "#apply" do
    let(:ecs_mock) { double }
    context "when updating service" do
      before do
        allow(adapter.ecs_service).to receive(:applied?) { true }
        allow(adapter.ecs_service).to receive_message_chain(:aws, :ecs) { ecs_mock }
      end

      context "when port_mappings is blank" do
        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [adapter.ecs_service.container_definition]
                               )
          expect(ecs_mock).to receive(:update_service)
                               .with(
                                 cluster: service.district.name,
                                 service: service.service_name,
                                 task_definition: service.service_name
                               )
          expect{adapter.apply}.to_not raise_error
        end
      end
    end

    context "when creating service" do
      before do
        allow(adapter.ecs_service).to receive(:applied?) { false }
        allow(adapter.ecs_service).to receive_message_chain(:aws, :ecs) { ecs_mock }
      end

      context "when port_mappings is blank" do
        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [
                                   {
                                     name: "awesome-app-web",
                                     cpu: 128,
                                     memory: 128,
                                     essential: true,
                                     image: 'nginx:1.9.5',
                                     environment: [],
                                     port_mappings: []
                                   }
                                 ]
                               )
          expect(ecs_mock).to receive(:create_service)
                               .with(
                                 cluster: service.district.name,
                                 service_name: service.service_name,
                                 task_definition: service.service_name,
                                 desired_count: 1
                               )
          expect{adapter.apply}.to_not raise_error
        end
      end

      context "when port_mappings is present" do
        let(:elb_mock) { double }
        let(:route53_mock) { double }

        before do
          allow(adapter.elb).to receive_message_chain(:aws, :elb) { elb_mock }
          allow(adapter.record_set).to receive_message_chain(:aws, :route53) { route53_mock }
          allow(adapter.elb).to receive(:fetch_load_balancer) { nil }
          service.port_mappings.create(lb_port: 80, container_port: 3000)
        end

        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
                               .with(
                                 family: service.service_name,
                                 container_definitions: [
                                   {
                                     name: "awesome-app-web",
                                     cpu: 128,
                                     memory: 128,
                                     essential: true,
                                     image: 'nginx:1.9.5',
                                     environment: [
                                       {name: "HOST_PORT_TCP_3000", value: Integer},
                                     ],
                                     port_mappings: [
                                       {container_port: 3000, protocol: "tcp", host_port: Integer}
                                     ]
                                   }
                                 ]
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
                                   cross_zone_load_balancing: {
                                     enabled: true
                                   },
                                   connection_draining: {
                                     enabled: true,
                                     timeout: 300
                                   }
                                 }
                               )
          expect(route53_mock).to receive(:get_hosted_zone) do
            double(hosted_zone: double(name: 'bcn.'))
          end
          expect(route53_mock).to receive(:change_resource_record_sets)
                                   .with(
                                     hosted_zone_id: service.district.private_hosted_zone_id,
                                     change_batch: {
                                       changes: [
                                         {
                                           action: "CREATE",
                                           resource_record_set: {
                                             name: "web.awesome-app.bcn.",
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
          expect{adapter.apply}.to_not raise_error
        end
      end
    end
  end

  describe "#delete" do
    let(:ecs_mock) { double }
    let(:route53_mock) { double }

    before do
      allow(adapter.ecs_service).to receive(:applied?) { true }
      allow(adapter.ecs_service).to receive_message_chain(:aws, :ecs) { ecs_mock }
      allow(adapter.record_set).to receive_message_chain(:aws, :route53) { route53_mock }
    end

    it "deletes ECS resources" do
      expect(ecs_mock).to receive(:update_service)
                           .with(
                             cluster: service.district.name,
                             service: service.service_name,
                             desired_count: 0
                           )
      expect(adapter.elb).to receive(:fetch_load_balancer) do
        OpenStruct.new(load_balancer_name: 'awesome-app-web', dns_name: 'dns.elb')
      end

      expect(ecs_mock).to receive(:delete_service)
                           .with(
                             cluster: service.district.name,
                             service: service.service_name
                           )

      expect(route53_mock).to receive(:get_hosted_zone) do
        double(hosted_zone: double(name: 'bcn.'))
      end
      expect(route53_mock).to receive(:change_resource_record_sets)
                               .with(
                                 hosted_zone_id: service.district.private_hosted_zone_id,
                                 change_batch: {
                                   changes: [
                                     {
                                       action: "DELETE",
                                       resource_record_set: {
                                         name: "web.awesome-app.bcn.",
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
      expect{adapter.delete}.to_not raise_error
    end
  end
end
