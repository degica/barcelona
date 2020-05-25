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
      ],
      failures: []
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
          ],
          failures: []
        )
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
          started_by: "barcelona",
          overrides: {
            container_overrides: [
              {
                name: heritage.name + "-oneoff",
                command: LaunchCommand.new(heritage, ["rake", "db:migrate"], shell_format: false).to_command,
                environment: [{name: "LANG", value: "C.UTF-8"}]
              }
            ]
          }
        ).and_return(describe_tasks_response_mock)
      oneoff.run
    end

    it "creates ECS task when interactive is true" do
      expect(ecs_mock).to receive(:run_task).
                            with(
                              cluster: heritage.district.name,
                              task_definition: "#{heritage.name}-oneoff",
                              started_by: "barcelona",
                              overrides: {
                                container_overrides: [
                                  {
                                    name: heritage.name + "-oneoff",
                                    command: ["/barcelona/barcelona-run", "watch-interactive-session"],
                                    environment: [{name: "LANG", value: "C.UTF-8"}]
                                  }
                                ]
                              }
                            ).and_return(describe_tasks_response_mock)
      oneoff.run(interactive: true)
    end

    it "creates ECS task with LANG set to C.UTF-8 even when interactive is false" do
      expect(ecs_mock).to receive(:run_task).
                            with(
                              hash_including(
                                overrides: hash_including(
                                  container_overrides: [hash_including(
                                    environment: [{name: "LANG", value: "C.UTF-8"}]
                                  )]
                                )
                              )
                            ).and_return(describe_tasks_response_mock)
      oneoff.run(interactive: false)
    end

    it 'uses env_var_arrayize to define environment' do
      allow(oneoff).to receive(:env_var_arrayize) { [{name: 'BAR', value: 'foo' }] }
      expect(ecs_mock).to receive(:run_task).with(hash_including(
        overrides: hash_including(
          container_overrides: [
            hash_including(environment: [{name: 'BAR', value: 'foo' }])
          ]
        )
      )).and_return(describe_tasks_response_mock)
      oneoff.run
    end
  end

  describe '#env_var_arrayize' do
    it 'arrayizes a hash' do
      result = oneoff.env_var_arrayize( "FOO" => "bar" )
      expect(result).to eq [{ name: 'FOO', value: 'bar' }]
    end

    it 'arrayizes a hash with multiple entries' do
      result = oneoff.env_var_arrayize( "FOO" => "bar", 'HELLO' => 'meow' )
      expect(result).to eq [{ name: 'FOO', value: 'bar' }, { name: 'HELLO', value: 'meow' }]
    end
  end
end
