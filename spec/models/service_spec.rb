require 'rails_helper'

describe Service do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }

  it { expect{service.save}.to_not raise_error }

  describe '#save_and_update_container_count!' do
    it 'saves and sets the container count' do
      expect(service.desired_container_count).to eq nil

      district = double('District')
      allow(service).to receive(:district) { district }
      allow(district).to receive(:name) { 'districtest' }

      ecs = double('ECS')
      allow(service).to receive(:ecs) { ecs }
      allow(service).to receive(:logical_name) { 'abc' }

      expect(ecs).to receive(:update_service).with({
        desired_count: 10,
        cluster: 'districtest',
        service: 'abc'
      })

      service.save_and_update_container_count!(10)

      expect(service.desired_container_count).to eq 10
    end
  end

  describe '#logical_name' do
    it 'gives the name of the service' do
      allow(service).to receive(:arn) { 'arn:aws:ecs:un-north-2:1234567890:service/testdistrict/testdistrict-testserv-abcdef' }

      expect(service.logical_name).to eq 'testdistrict-testserv-abcdef'
    end

    it 'throws an error is arn is nil' do
      allow(service).to receive(:arn) { nil }

      expect{service.logical_name}.to raise_error Service::ServiceNotFoundException
    end
  end

  describe '#arn' do
    it 'searches the array and finds the ARN' do
      allow(service).to receive(:service_arns) { ['arn:hello', 'ggg:hello'] }
      allow(service).to receive(:arn_prefix) { 'arn:' }

      expect(service.arn).to eq 'arn:hello'
    end

    it 'returns nil if no ARN' do
      allow(service).to receive(:service_arns) { ['kkk:hello', 'ggg:hello'] }
      allow(service).to receive(:arn_prefix) { 'arn:' }

      expect(service.arn).to be_nil
    end
  end

  describe '#service_arns' do
    it 'returns service arns' do
      district = double('District', name: 'testdistrict')

      result = double('PaginatedSawyer')
      allow(result).to receive(:service_arns) { ['abc'] }

      ecs = double('ECS')
      allow(ecs).to receive(:list_services).with(cluster: 'testdistrict') { result }

      allow(service).to receive(:district) { district }
      allow(service).to receive(:ecs) { ecs }

      expect(service.service_arns).to eq ['abc']
    end
  end

  describe '#arn_prefix' do
    it 'produces a prefix for the arn' do
      district = double('District',
        region: 'un-north-2',
        name: 'testdistrict',
        aws: double('AWS',
          sts: double('STS', get_caller_identity: {
            account: '1234567890'
          })
        )
      )
      allow(service).to receive(:district) { district }
      allow(service).to receive(:service_name) { 'testserv' }

      expect(service.arn_prefix).to eq 'arn:aws:ecs:un-north-2:1234567890:service/testdistrict/testdistrict-testserv'
    end
  end

  describe 'handling port mappings' do
    context 'created with default port' do
      before { service.save }
      it 'should create http and https port mappings' do
        expect(service.port_mappings).to have(2).items
        http_mapping = service.port_mappings.find_by_lb_port(80)
        expect(http_mapping.container_port).to eq(Service::WEB_CONTAINER_PORT_DEFAULT)
        https_mapping = service.port_mappings.find_by_lb_port(443)
        expect(https_mapping.container_port).to eq(Service::WEB_CONTAINER_PORT_DEFAULT)
      end
    end

    context 'created with specified port' do
      before { service.save }
      let(:service) { create :web_service, heritage: heritage, web_container_port: 6000 }
      it 'should create http and https port mappings with the specifed port' do
        expect(service.port_mappings).to have(2).items
        http_mapping = service.port_mappings.find_by_lb_port(80)
        expect(http_mapping.container_port).to eq(6000)
        https_mapping = service.port_mappings.find_by_lb_port(443)
        expect(https_mapping.container_port).to eq(6000)
      end
    end

    context 'update specified port' do
      before do
        service.save
        service.web_container_port = 6000
        service.save
      end

      it 'should create http and https port mappings with the specifed port' do
        expect(service.port_mappings).to have(2).items
        http_mapping = service.port_mappings.find_by_lb_port(80)
        expect(http_mapping.container_port).to eq(6000)
        https_mapping = service.port_mappings.find_by_lb_port(443)
        expect(https_mapping.container_port).to eq(6000)
      end
    end

    context 'created with specified port and extra mapping' do
      before { service.save }
      let(:udp_mapping) { PortMapping.new(container_port: 3333, protocol: "udp", lb_port: 3333) }
      let(:service) do
        create :web_service, heritage: heritage, web_container_port: 6000, port_mappings: [udp_mapping]
      end
      it 'should create http and https port mappings with the specifed port' do
        expect(service.port_mappings).to have(3).items
        http_mapping = service.port_mappings.find_by_lb_port(80)
        expect(http_mapping.container_port).to eq(6000)
        https_mapping = service.port_mappings.find_by_lb_port(443)
        expect(https_mapping.container_port).to eq(6000)
        udp_mapping = service.port_mappings.find_by_lb_port(3333)
        expect(udp_mapping.container_port).to eq(3333)
      end
    end
  end
end
