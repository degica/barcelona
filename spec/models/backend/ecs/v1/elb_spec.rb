require "rails_helper"

describe Backend::Ecs::V1::Elb do
  let(:service) { create :web_service }

  describe "#health_check_target" do
    subject { described_class.new(service).health_check_target }
#    context "when a target is HTTP" do
#      before do
#        service.update!(health_check: {protocol: "http", http_path: "/health_check"})
#      end
#      it { is_expected.to eq "HTTP:#{service.http_port_mapping.host_port}/health_check"}
#    end
#
#    context "when a target is HTTPS" do
#      before do
#        service.update!(health_check: {protocol: "https", http_path: "/health_check"})
#      end
#      it { is_expected.to eq "HTTPS:#{service.https_port_mapping.host_port}/health_check"}
#    end

    context "when a target is TCP" do
      before do
        service.update!(health_check: {protocol: "tcp", port: 1111})
      end
      it { is_expected.to eq "TCP:1111"}
    end

    context "when health_check is blank" do
      it { is_expected.to eq "TCP:#{service.port_mappings.first.host_port}"}
    end
  end
end
