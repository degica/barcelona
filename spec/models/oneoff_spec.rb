require 'rails_helper'

describe Oneoff do
  let(:ecs_mock) { double }
  let(:heritage) { create :heritage }
  let(:oneoff) { create :oneoff, heritage: heritage, command: "rake db:migrate" }

  describe "#running?" do
    before do
      allow(oneoff).to receive_message_chain(:aws, :ecs, :describe_tasks) {
        double(
          tasks: [
            double(
              containers: [
                double(last_status: "STOPPED")
              ])
          ])
      }
    end

    it { expect(oneoff.running?).to eq false }
  end

  describe "#run" do
    before do
      allow(oneoff).to receive_message_chain(:aws, :ecs) { ecs_mock }
    end

    it "creates ECS task" do
      expect(ecs_mock).to receive(:register_task_definition).
        with(
          family: "#{heritage.name}-oneoff",
          container_definitions: [
            {
              name: heritage.name + "-oneoff",
              cpu: 256,
              memory: 256,
              essential: true,
              image: "#{heritage.image_path}",
              environment: []
            }
          ]
        )
      expect(ecs_mock).to receive(:run_task).
        with(
          cluster: heritage.district.name,
          task_definition: "#{heritage.name}-oneoff",
          overrides: {
            container_overrides: [
              {
                name: heritage.name + "-oneoff",
                command: ["sh", "-c", "exec rake db:migrate"],
                environment: []
              }
            ]
          }
        ).and_return(double(tasks: [double(task_arn: 'arn')]))
      oneoff.run
    end

    context "when attributes are overwrite" do
      let(:oneoff) {
        create :oneoff,
               heritage: heritage,
               command: "rake db:migrate",
               image_tag: "v100",
               env_vars: {"OVERRITE_ENV" => "VALUE"}
      }
      it "creates ECS task" do
        expect(ecs_mock).to receive(:register_task_definition).
          with(
            family: "#{heritage.name}-oneoff",
            container_definitions: [
              {
                name: heritage.name + "-oneoff",
                cpu: 256,
                memory: 256,
                essential: true,
                image: "#{heritage.image_name}:v100",
                environment: []
              }
            ]
          )
        expect(ecs_mock).to receive(:run_task).
          with(
            cluster: heritage.district.name,
            task_definition: "#{heritage.name}-oneoff",
            overrides: {
              container_overrides: [
                {
                  name: heritage.name + "-oneoff",
                  command: ["sh", "-c", "exec rake db:migrate"],
                  environment: [
                    {name: "OVERRITE_ENV", value: "VALUE"}
                  ]
                }
              ]
            }
          ).and_return(double(tasks: [double(task_arn: 'arn')]))
        oneoff.run
      end
    end
  end
end
