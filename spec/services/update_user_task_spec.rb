require 'rails_helper'

describe UpdateUserTask do
  let(:user) { create :user, public_key: 'ssh-rsa aaaabbbb' }
  let(:district) { create :district, dockercfg: {"quay.io" => {"auth" => "abcdef"}} }
  let(:section) { district.sections[:private] }
  let(:task) { described_class.new(section, user) }
  let(:ecs_mock) { double }
  let(:container_instance_arn) { "arn:aws:ecs:ap-northeast-1:822761295011:container-instance/13da152c-605b-4b37-9ef0-de87be9e50f2" }

  before do
    allow(task).to receive_message_chain(:aws, :ecs) { ecs_mock }
  end

  context "the section has one containter instance running" do
    before do
      allow(section).to receive(:container_instances).and_return [
        {
          "status":"ACTIVE",
          "container_instance_arn": container_instance_arn,
          "remaining_resources": [],
          "running_tasks_count":4,
          "pending_tasks_count":0,
          "private_ip_address":"10.67.1.121",
          "ec2_instance_id":"i-b80e791d"
        }
      ]
    end

    it "updates users on every container instance" do
      expect(ecs_mock).to receive(:register_task_definition)
                           .with(
                             family: 'update_user',
                             container_definitions: [
                               {
                                 name: "update_user",
                                 cpu: 32,
                                 memory: 64,
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
                             container_instances: [container_instance_arn]
                           )
      task.run
    end
  end

  context "the section has no containter instance running" do
    before do
      allow(section).to receive(:container_instances).and_return [
      ]
    end
    it "does nothing" do
      expect(ecs_mock).not_to receive(:register_task_definition)
      expect(ecs_mock).not_to receive(:start_task)
      task.run
    end
  end
end
