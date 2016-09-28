require 'rails_helper'

describe Oneoff do
  let(:ecs_mock) { double }
  let(:describe_tasks_response_mock) {
    double(
      tasks: [
        double(
          task_arn: "arns",
          containers: [
            double(
              name: "#{heritage.name}-oneoff",
              container_arn: "container-arn"
            )
          ]
        )
      ]
    )
  }
  let(:heritage) { create :heritage }
  let(:oneoff) { create :oneoff, heritage: heritage, command: "rake db:migrate" }

  describe "#stopped?" do
    before do
      allow(oneoff).to receive_message_chain(:aws, :ecs, :describe_tasks) {
        double(
          tasks: [
            double(last_status: "STOPPED")
          ])
      }
    end

    it { expect(oneoff.stopped?).to eq true }
  end

  describe "#run" do
    before do
      allow(oneoff).to receive_message_chain(:aws, :ecs) { ecs_mock }
      expect(ecs_mock).to receive(:register_task_definition)
    end

    it "creates ECS task" do
      expect(ecs_mock).to receive(:run_task).
        with(
          cluster: heritage.district.name,
          task_definition: "#{heritage.name}-oneoff",
          overrides: {
            container_overrides: [
              {
                name: heritage.name + "-oneoff",
                command: LaunchCommand.new(heritage, oneoff.command).to_command
              }
            ]
          }
        ).and_return(describe_tasks_response_mock)
      oneoff.run
    end
  end
end
