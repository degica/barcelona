require 'rails_helper'

describe Service do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }

  it { expect{service.save}.to_not raise_error }

  describe '#create_port_mappings' do
    before do
      service.port_mappings.destroy_all
    end

    it 'creates http port mappings when they do not exist' do
      allow(service).to receive(:web?) { true }
      allow(service).to receive(:http_port_mapping) { nil }

      service.send :create_port_mappings

      expect(service.port_mappings.find_by(protocol: 'http')).to be_present
    end

    it 'creates https port mappings when they do not exist' do
      allow(service).to receive(:web?) { true }
      allow(service).to receive(:https_port_mapping) { nil }

      service.send :create_port_mappings

      expect(service.port_mappings.find_by(protocol: 'https')).to be_present
    end

    it 'does not create https port mappings when not a web' do
      allow(service).to receive(:web?) { false }
      allow(service).to receive(:https_port_mapping) { nil }

      service.send :create_port_mappings

      expect(service.port_mappings.find_by(protocol: 'https')).to be_blank
    end
  end
end
