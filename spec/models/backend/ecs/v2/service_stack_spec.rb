require 'rails_helper'

describe Backend::Ecs::V2::ServiceStack do
  let(:service) { create :service }
  let(:task_definition) { HeritageTaskDefinition.service_definition(service).to_task_definition }
  let(:stack) { described_class.new(service, task_definition, 1) }

  context "when the service doesn't have autoscaling" do
    it "generates basic resources" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["ECSServiceRole"]).to be_present
      expect(generated["Resources"]["ECSService"]).to be_present
    end

    it "doesn't generate other resources" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["ScalableTarget"]).to_not be_present
      expect(generated["Resources"]["ScaleUpPolicy"]).to_not be_present
      expect(generated["Resources"]["ScaleDownPolicy"]).to_not be_present
      expect(generated["Resources"]["ServiceCPUAlarm"]).to_not be_present
      expect(generated["Resources"]["AASRole"]).to_not be_present
    end
  end

  context "when the service has autoscaling" do
    before do
      service.auto_scaling = {max_count: 10, min_count: 2}
    end

    it "generates resources" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["ECSServiceRole"]).to be_present
      expect(generated["Resources"]["ECSService"]).to be_present
      expect(generated["Resources"]["ScalableTarget"]).to be_present
      expect(generated["Resources"]["ScaleUpPolicy"]).to be_present
      expect(generated["Resources"]["ScaleDownPolicy"]).to be_present
      expect(generated["Resources"]["ServiceCPUAlarm"]).to be_present
      expect(generated["Resources"]["AASRole"]).to be_present
    end
  end

  context "when a service is TCP mode" do
    before do
      service.port_mappings.create!(container_port: 3000, lb_port: 80)
    end

    it "generates resources" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["ECSServiceRole"]).to be_present
      expect(generated["Resources"]["ECSService"]).to be_present
      expect(generated["Resources"]["ClassicLoadBalancer"]).to be_present
      expect(generated["Resources"]["RecordSet"]).to be_present
      expect(generated["Resources"]["LBTargetGroup1"]).to_not be_present
      expect(generated["Resources"]["LBListenerRuleHTTP"]).to_not be_present
      expect(generated["Resources"]["LBListenerRuleHTTPS"]).to_not be_present
    end
  end

  context "when a service is ALB mode" do
    context "when the service has autoscaling and listeners" do
      let(:endpoint) { create :endpoint }

      before do
        service.listeners << endpoint.listeners.new
        allow_any_instance_of(Endpoint).to receive(:https_listener_id) { "https-listener-id" }
      end

      it "generates resources" do
        generated = JSON.load stack.target!
        expect(generated["Resources"]["ECSServiceRole"]).to be_present
        expect(generated["Resources"]["ECSService"]).to be_present
        expect(generated["Resources"]["LBTargetGroup1"]).to be_present
        expect(generated["Resources"]["LBListenerRuleHTTP"]).to be_present
        expect(generated["Resources"]["LBListenerRuleHTTPS"]).to be_present
        expect(generated["Resources"]["ClassicLoadBalancer"]).to_not be_present
      end
    end
  end
end
