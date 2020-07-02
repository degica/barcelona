require 'rails_helper'

describe Service do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }

  it { expect{service.save}.to_not raise_error }

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
