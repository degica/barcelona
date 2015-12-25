require 'rails_helper'

describe TerminateInstanceTask do
  let(:district) { create :district, dockercfg: {"quay.io" => {"auth" => "abcdef"}} }
  let(:section) { district.sections[:private] }
  let(:task) { described_class.new(section) }
  let(:ecs_mock) { double }

  before do
    allow(task).to receive_message_chain(:aws, :ecs) { ecs_mock }
  end
  it "updates users on every container instance" do
    expect(ecs_mock).to receive(:register_task_definition).
      with(
        family: 'terminate-instance',
        container_definitions: [
          {
            name: "terminate-instance",
            cpu: 32,
            memory: 96,
            essential: true,
            image: "k2nr/ecs-instance-terminator",
            environment: [],
            mount_points: [
              {
                source_volume: "docker-socket",
                container_path: "/var/run/docker.sock"
              }
            ]
          }
        ],
        volumes: [
          {
            name: "docker-socket",
            host: {
              source_path: "/var/run/docker.sock"
            }
          }
        ]
      )

    expect(ecs_mock).to receive(:start_task).
      with(
        cluster: section.cluster_name,
        task_definition: "terminate-instance",
        overrides: {
          container_overrides: [
            {
              name: "terminate-instance",
              environment: [
                {name: "STOP_TIMEOUT", value: "120"},
                {name: "AWS_REGION", value: "ap-northeast-1"}
              ]
            }
          ]
        },
        container_instances: "container_instance_arn"
      )
    task.run("container_instance_arn")
  end
end
