require 'rails_helper'

describe PortMapping do
  let(:service) { create :web_service }
  describe ".create" do
    it "sets default protocol" do
      port_mapping = service.port_mappings.create!(container_port: 3000, lb_port: 80)
      expect(port_mapping.protocol).to eq "tcp"
    end

    context "when host_port is not specified" do
      let(:port_mapping) { service.port_mappings.create!(container_port: 3000, lb_port: 80) }
      it "auto-assigns a host port" do
        expect(port_mapping.host_port).to be_a Integer
      end
    end

    context "when host_port is specified" do
      let(:port_mapping) { service.port_mappings.create!(container_port: 3000, lb_port: 80, host_port: 3000) }
      it { expect(port_mapping.host_port).to eq 3000 }
    end
  end

  describe "validations" do
    it "allows host_port range 1024 - 19999" do
      port_mapping = service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 1023)
      expect(port_mapping).to_not be_valid
      port_mapping = service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 20001)
      expect(port_mapping).to_not be_valid
    end

    it "validates host port uniqueness" do
      port_mapping1 = service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 10000)
      expect(port_mapping1).to be_valid
      port_mapping2 = service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 10000)
      expect(port_mapping2).to_not be_valid
    end

    it "can be same host port if mappings belong to different distrects" do
      another_service = create :web_service
      port_mapping1 = service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 10000)
      expect(port_mapping1).to be_valid
      port_mapping2 = another_service.port_mappings.create(container_port: 3000, lb_port: 80, host_port: 10000)
      expect(port_mapping2).to be_valid
    end
  end
end
