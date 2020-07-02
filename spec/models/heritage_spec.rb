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

  describe "legacy env_var and declarative env combinations" do
    subject { heritage.environment_set.sort_by { |e| e[:name] } }
    let(:heritage) { create :heritage }

    context "when only env_vars exist" do
      before do
        heritage.env_vars.create!(key: "env", value: "value")
      end

      it { is_expected.to eq [{name: "env", value: "value"}]}
    end

    context "when only environment exist" do
      before do
        heritage.environments.create!(name: "env", value: "value")
      end
      it { is_expected.to eq [{name: "env", value: "value"}]}
    end

    context "when both exist" do
      before do
        heritage.env_vars.create!(key: "env", value: "value")
        heritage.env_vars.create!(key: "env2", value: "value2")
        heritage.environments.create!(name: "env", value: "value_new")
        heritage.environments.create!(name: "env3", value: "value3")
      end

      it { is_expected.to eq [{name: "env", value: "value_new"},
                              {name: "env2", value: "value2"},
                              {name: "env3", value: "value3"}]}
    end
  end

  describe "#legacy_secrets" do
    subject { heritage.legacy_secrets.order("key").pluck(:key) }
    let(:heritage) { create :heritage }

    context "when there are only legacy secrets" do
      before do
        heritage.env_vars.create!(key: "env", value: "abc", secret: true)
        heritage.env_vars.create!(key: "env2", value: "abc", secret: true)
      end

      it { is_expected.to eq ["env", "env2"] }
    end

    context "when there are both legacy secrets and value_from" do
      before do
        heritage.env_vars.create!(key: "env", value: "abc", secret: true)
        heritage.env_vars.create!(key: "env2", value: "abc", secret: true)
        heritage.environments.create!(name: "env", value_from: "arn")
        heritage.environments.create!(name: "env3", value_from: "arn")
      end

      it { is_expected.to eq ["env2"] }
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
                                                command: 'rails runner "p :hello"'}] }
      it "generates a correct stack template" do
        generated = JSON.load stack.target!
        expect(generated["Resources"]["ScheduleTaskDefinition"]).to be_present
        expect(generated["Resources"]["ScheduledEvent0"]).to be_present
        expected_input = {
          cluster: heritage.district.name,
          task_family: "#{heritage.name}-schedule",
          command: LaunchCommand.new(heritage, ["rails", "runner", "p :hello"], shell_format: false).to_command
        }.to_json
        expect(generated["Resources"]["ScheduledEvent0"]["Properties"]["Targets"][0]["Input"]).to eq(expected_input)
        expect(generated["Resources"]["PermissionForScheduledEvent0"]).to be_present
        expect(generated["Resources"]["ScheduleHandler"]).to be_present
        expect(generated["Resources"]["ScheduleHandlerRole"]).to be_present
      end
    end
  end
end
