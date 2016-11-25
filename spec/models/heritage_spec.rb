require 'rails_helper'

describe Heritage do
  let(:heritage) { build :heritage }

  describe "#save_and_deploy!" do
    it "enqueues deploy job" do
      expect(DeployRunnerJob).to receive(:perform_later).with(heritage,
                                                              without_before_deploy: false,
                                                              description: "deploy")
      release = heritage.save_and_deploy!(description: "deploy")
      expect(release.description).to eq "deploy"
    end
  end

  describe "#describe_services" do
    it { expect(heritage.describe_services).to eq [] }
  end

  describe "#image_path" do
    context "when image_name is blank" do
      let(:heritage) { build :heritage, image_name: nil, image_tag: nil }
      it { expect(heritage.image_path).to be_nil }
    end

    context "when image_name is present" do
      let(:heritage) { build :heritage, image_name: 'nginx', image_tag: nil }
      it { expect(heritage.image_path).to eq "nginx:latest" }
    end

    context "when image_tag is present" do
      let(:heritage) { build :heritage, image_name: 'nginx', image_tag: "master" }
      it { expect(heritage.image_path).to eq "nginx:master" }
    end
  end
end

describe Heritage::Stack do
  let(:heritage) { build :heritage }
  let(:stack) { described_class.new(heritage) }

  describe "#target!" do
    it "generates a correct stack template" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["LogGroup"]).to be_present
      expect(generated["Resources"]["TaskRole"]).to be_present
    end

    context "when a heritage has scheduled tasks" do
      let(:heritage) { build :heritage,
                             scheduled_tasks: [{schedule: 'rate(1 minute)',
                                                command: 'echo hello'}] }
      it "generates a correct stack template" do
        generated = JSON.load stack.target!
        expect(generated["Resources"]["ScheduleTaskDefinition"]).to be_present
        expect(generated["Resources"]["ScheduledEvent0"]).to be_present
        expect(generated["Resources"]["PermissionForScheduledEvent0"]).to be_present
        expect(generated["Resources"]["ScheduleHandler"]).to be_present
        expect(generated["Resources"]["ScheduleHandlerRole"]).to be_present
      end
    end
  end
end
