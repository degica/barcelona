require 'rails_helper'

describe UpdateUserTask do
  let(:user) { create :user, public_key: 'ssh-rsa aaaabbbb' }
  let(:district) { create :district, dockercfg: {"quay.io" => {"auth" => "abcdef"}} }
  let(:section) { district.sections[:private] }
  let(:task) { described_class.new(section, user) }
  let(:ecs_mock) { double }

  before do
    allow(task).to receive_message_chain(:aws, :ecs) { ecs_mock }
  end
  it "updates users on every container instance" do
    expect(ecs_mock).to receive(:register_task_definition)
                         .with(
                           family: 'update_user',
                           container_definitions: [
                             {
                               name: "update_user",
                               cpu: 32,
                               memory: 32,
                               essential: true,
                               image: "k2nr/docker-user-manager",
                               mount_points: [
                                 {
                                   source_volume: "etc",
                                   container_path: "/etc"
                                 },
                                 {
                                   source_volume: "home",
                                   container_path: "/home"
                                 }
                               ],
                               environment: []
                             }
                           ],
                           volumes: [
                             {
                               name: "etc",
                               host: {
                                 source_path: "/etc"
                               }
                             },
                             {
                               name: "home",
                               host: {
                                 source_path: "/home"
                               }
                             }
                           ]
                         )

    expect(ecs_mock).to receive(:start_task)
                         .with(
                           cluster: section.cluster_name,
                           task_definition: "update_user",
                           overrides: {
                             container_overrides: [
                               {
                                 name: "update_user",
                                 environment: [
                                   {name: "USER_NAME", value: user.name},
                                   {name: "USER_GROUPS", value: "docker"},
                                   {name: "USER_PUBLIC_KEY", value: user.public_key},
                                   {name: "USER_DOCKERCFG", value: section.dockercfg.to_json}
                                 ]
                               }
                             ]
                           },
                           container_instances: section.container_instances.map{ |c| c[:container_instance_arn] }
                         )
    task.run
  end
end
