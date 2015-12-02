require 'rails_helper'

describe Backend::Ecs::Adapter do
  let(:heritage) { create :heritage }
  let(:adapter) { described_class.new(service) }

  describe "#apply" do
    let(:ecs_mock) { double }
    let(:service) { create :web_service, heritage: heritage }
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
        let(:service) { create :web_service, heritage: heritage }
        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
          .with(
            family: service.service_name,
            container_definitions: [
              {
                name: service.service_name,
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
        let(:service) { create :web_service, heritage: heritage, service_type: 'web' }
        let(:port_http) { service.port_mappings.http }
        let(:port_https) { service.port_mappings.https }

        before do
          allow(adapter.elb).to receive_message_chain(:aws, :elb) { elb_mock }
          allow(adapter.record_set).to receive_message_chain(:aws, :route53) { route53_mock }
          allow(adapter.elb).to receive(:fetch_load_balancer) { nil }
          @port_tcp = service.port_mappings.create(lb_port: 1111, container_port: 1111)
        end

        it "create ECS resources" do
          expect(ecs_mock).to receive(:register_task_definition)
          .with(
            family: service.service_name,
            container_definitions: [
              {
                name: service.service_name,
                cpu: 128,
                memory: 128,
                essential: true,
                image: 'nginx:1.9.5',
                environment: [
                  {name: "HOST_PORT_HTTP_3000", value: port_http.host_port.to_s},
                  {name: "HOST_PORT_HTTPS_3000", value: port_https.host_port.to_s},
                  {name: "HOST_PORT_TCP_1111", value: @port_tcp.host_port.to_s}
                ],
                port_mappings: [
                  {container_port: 3000, protocol: "tcp"},
                  {container_port: 1111, protocol: "tcp", host_port: @port_tcp.host_port}
                ]
              },
              {
                name: "#{service.service_name}-revpro",
                cpu: 128,
                memory: 128,
                essential: true,
                image: "k2nr/reverse-proxy:latest",
                links: ["#{service.service_name}:backend"],
                environment: [
                  {name: "AWS_REGION", value: "ap-northeast-1"},
                  {name: "UPSTREAM_NAME", value: "backend"},
                  {name: "UPSTREAM_PORT", value: "3000"}
                ],
                port_mappings: [
                  {
                    container_port: 80,
                    host_port: port_http.host_port,
                    protocol: "tcp"
                  },
                  {
                    container_port: 443,
                    host_port: port_https.host_port,
                    protocol: "tcp"
                  }
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
                load_balancer_name: service.service_name,
                container_name: service.service_name + "-revpro",
                container_port: 80
              }
            ],
            role: service.district.ecs_service_role,
            desired_count: 1
          )
          expect(elb_mock).to receive(:create_load_balancer)
          .with(
            load_balancer_name: service.service_name,
            subnets: [],
            scheme: 'internet-facing',
            security_groups: [service.district.public_elb_security_group],
            listeners: [
              {
                protocol: 'TCP',
                load_balancer_port: 80,
                instance_protocol: 'TCP',
                instance_port: port_http.host_port
              },
              {
                protocol: 'TCP',
                load_balancer_port: 443,
                instance_protocol: 'TCP',
                instance_port: port_https.host_port
              },
              {
                protocol: 'TCP',
                load_balancer_port: 1111,
                instance_protocol: 'TCP',
                instance_port: @port_tcp.host_port
              }
            ]
          )
          .and_return(OpenStruct.new(dns_name: 'dns.internal'))
          expect(elb_mock).to receive(:configure_health_check)
          .with(
            load_balancer_name: service.service_name,
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
            load_balancer_name: service.service_name,
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
          expect(elb_mock).to receive(:create_load_balancer_policy)
          expect(elb_mock).to receive(:set_load_balancer_policies_for_backend_server).twice
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
                    name: "#{service.name}.#{service.heritage.name}.bcn.",
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
    let(:service) { create :web_service, heritage: heritage }

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
        OpenStruct.new(load_balancer_name: service.service_name, dns_name: 'dns.elb')
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
                name: "#{service.name}.#{service.heritage.name}.bcn.",
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
