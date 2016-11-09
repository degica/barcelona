require 'rails_helper'

describe Backend::Ecs::V2::ServiceStack do
  let(:service) { create :service }
  let(:task_definition) { HeritageTaskDefinition.service_definition(service).to_task_definition }
  let(:stack) { described_class.new(service, task_definition, 1) }

  it "generates resources" do
    generated = JSON.load stack.target!
    expect(generated["Resources"]["ECSServiceRole"]).to be_present
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
    end
  end
end
