require 'rails_helper'

describe Backend::Ecs::V2::ServiceStack do
  let(:service) { create :service }
  let(:task_definition) { HeritageTaskDefinition.service_definition(service).to_task_definition }
  let(:stack) { described_class.new(service) }

  before do
    stack.task_definition = task_definition
    stack.desired_count = 1
  end

  it "generates resources" do
    generated = JSON.load stack.target!
    expect(generated["Resources"]["ECSServiceRole"]).to_not be_present
    expect(generated["Resources"]["ECSService"]).to be_present
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
      expect(generated["Resources"]["ECSServiceRole"]).to be_present
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
        expect(generated["Resources"]["ECSServiceRole"]).to be_present
      end

      it "generates a service with a proper DeploymentConfiguration" do
        generated = JSON.load stack.target!
        generated_service = generated["Resources"]["ECSService"]
        expect(generated_service["Type"]).to eq("AWS::ECS::Service")
        expect(generated_service["Properties"]["DesiredCount"]).to eq(1)
        deployment_configuration = {
          "MaximumPercent" => 150,
          "MinimumHealthyPercent" => 100
        }
        expect(generated_service["Properties"]["DeploymentConfiguration"]).to eq(deployment_configuration)
      end
    end
  end
end
