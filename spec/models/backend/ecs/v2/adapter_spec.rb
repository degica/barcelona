require 'rails_helper'

describe Backend::Ecs::V2::Adapter do
  describe '#apply' do
    it "sets desired count to 1" do
      service = create :service, desired_container_count: 1
      adapter = described_class.new(service)
      expect(adapter).to receive(:cf_executor).with(anything, 1).and_call_original

      adapter.apply
    end

    it "sets desired count to whatever it was" do
      service = create :service

      adapter = described_class.new(service)
      ecs_service = instance_double('something')
      allow(ecs_service).to receive(:desired_count) { 5 }
      allow(adapter).to receive(:ecs_service) { ecs_service }
      expect(adapter).to receive(:cf_executor).with(anything, 5).and_call_original

      adapter.apply
    end

    it "service desired_container_count overrides current existing count" do
      service = create :service, desired_container_count: 2

      adapter = described_class.new(service)
      ecs_service = instance_double('something')
      allow(ecs_service).to receive(:desired_count) { 5 }
      allow(adapter).to receive(:ecs_service) { ecs_service }
      expect(adapter).to receive(:cf_executor).with(anything, 2).and_call_original

      adapter.apply
    end
  end
end
