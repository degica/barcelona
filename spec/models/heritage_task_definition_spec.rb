require "rails_helper"

describe HeritageTaskDefinition do
  let(:expected_log_configuration) {
    {
      log_driver: "awslogs",
      options: {
        "awslogs-group" => heritage.log_group_name,
        "awslogs-region" => district.region,
        "awslogs-stream-prefix" => heritage.name
      }
    }
  }

  describe ".service_definition" do
    subject { described_class.service_definition(service).to_task_definition }
    let(:district) { create :district }
    let(:heritage) { create :heritage, version: 1, district: district }
    let(:service)  { create :service, heritage: heritage }

    before do
      allow(heritage).to receive(:task_role_id) { "task-role" }
      allow(heritage).to receive(:task_execution_role_id) { "task-execution-role" }
    end

    it "returns a task definition for the service" do
      expect(subject).to eq({
                              family: service.service_name,
                              task_role_arn: "task-role",
                              execution_role_arn: "task-execution-role",
                              container_definitions: [
                                {
                                  name: service.service_name,
                                  cpu: service.cpu,
                                  memory: service.memory,
                                  essential: true,
                                  image: heritage.image_path,
                                  command: LaunchCommand.new(heritage, service.command).to_command,
                                  environment: [],
                                  secrets: [],
                                  volumes_from: [
                                    {
                                      source_container: "runpack",
                                      read_only: true
                                    }
                                  ],
                                  log_configuration: expected_log_configuration
                                },
                                {
                                  name: "runpack",
                                  cpu: 1,
                                  memory: 16,
                                  essential: false,
                                  image: "quay.io/degica/barcelona-run-pack",
                                  environment: [],
                                  secrets: [],
                                  log_configuration: expected_log_configuration
                                }
                              ]
                           })
    end

    context "when a service is web service" do
      let(:service) { create :web_service, heritage: heritage }
      it "returns a task definition for the service" do
        expect(subject).to eq({
                                family: service.service_name,
                                task_role_arn: "task-role",
                                execution_role_arn: "task-execution-role",
                                container_definitions: [
                                  {
                                    environment: [
                                      {
                                        name: "HOST_PORT_HTTP_3000",
                                        value: service.http_port_mapping.host_port.to_s
                                      },
                                      {
                                        name: "HOST_PORT_HTTPS_3000",
                                        value: service.https_port_mapping.host_port.to_s
                                      },
                                      {
                                        name: "PORT",
                                        value: "3000"
                                      }
                                    ],
                                    secrets: [],
                                    name: service.service_name,
                                    cpu: service.cpu,
                                    memory: service.memory,
                                    essential: true,
                                    image: heritage.image_path,
                                    command: LaunchCommand.new(heritage, service.command).to_command,
                                    volumes_from: [
                                      {
                                        source_container: "runpack",
                                        read_only: true
                                      }
                                    ],
                                    port_mappings: [
                                      {container_port: 3000, protocol: "tcp"}
                                    ],
                                    log_configuration: expected_log_configuration
                                  },
                                  {
                                    name: "runpack",
                                    cpu: 1,
                                    memory: 16,
                                    essential: false,
                                    image: "quay.io/degica/barcelona-run-pack",
                                    environment: [],
                                    secrets: [],
                                    log_configuration: expected_log_configuration
                                  },
                                  {
                                    name: "#{service.service_name}-revpro",
                                    cpu: 128,
                                    memory: 128,
                                    essential: true,
                                    image: service.reverse_proxy_image,
                                    links: ["#{service.service_name}:backend"],
                                    environment: [
                                      {
                                        name: "AWS_REGION",
                                        value: district.region,
                                      },
                                      {
                                        name: "UPSTREAM_NAME",
                                        value: "backend"
                                      },
                                      {
                                        name: "UPSTREAM_PORT",
                                        value: "3000"
                                      },
                                      {
                                        name: "FORCE_SSL",
                                        value: "false"
                                      }
                                    ],
                                    secrets: [],
                                    port_mappings: [
                                      {
                                        container_port: 80,
                                        host_port: service.http_port_mapping.host_port,
                                        protocol: "tcp"
                                      },
                                      {
                                        container_port: 443,
                                        host_port: service.https_port_mapping.host_port,
                                        protocol: "tcp"
                                      }
                                    ],
                                    log_configuration: expected_log_configuration
                                  }
                                ]
                              })
      end
    end
  end

  describe ".oneonff_definition" do
    subject { described_class.oneoff_definition(oneoff).to_task_definition }
    let(:oneoff) { create :oneoff }
    let(:heritage) { oneoff.heritage }
    let(:district) { oneoff.district }

    before do
      allow(heritage).to receive(:task_role_id) { "task-role" }
      allow(heritage).to receive(:task_execution_role_id) { "task-execution-role" }
    end

    it "returns a task definition for the oneoff" do
      expect(subject).to eq({
                              family: "#{heritage.name}-oneoff",
                              task_role_arn: "task-role",
                              execution_role_arn: "task-execution-role",
                              container_definitions: [
                                {
                                  name:  "#{heritage.name}-oneoff",
                                  cpu: 128,
                                  memory: 512,
                                  essential: true,
                                  image: heritage.image_path,
                                  environment: [],
                                  secrets: [],
                                  volumes_from: [
                                    {
                                      source_container: "runpack",
                                      read_only: true
                                    }
                                  ],
                                  log_configuration: expected_log_configuration
                                },
                                {
                                  name: "runpack",
                                  cpu: 1,
                                  memory: 16,
                                  essential: false,
                                  image: "quay.io/degica/barcelona-run-pack",
                                  environment: [],
                                  secrets: [],
                                  log_configuration: expected_log_configuration
                                }
                              ]
                           })
    end

    context "when session_token is not nil" do
      it "sets user to task definition" do
        oneoff.session_token = 'session-token'
        expect(subject[:container_definitions][0][:docker_labels]).to eq({"com.barcelona.oneoff-id" => 'session-token'})
      end
    end

    context "when user is specified" do
      it "sets user to task definition" do
        oneoff.user = "user"
        expect(subject[:container_definitions][0][:user]).to eq("user")
      end
    end
  end

  describe ".schedule_definition" do
    subject { described_class.schedule_definition(heritage).to_task_definition(camelize: true) }
    let(:heritage) { create :heritage }
    let(:district) { heritage.district }
    let(:expected_log_configuration) {
      {
        "LogDriver" => "awslogs",
        "Options" => {
          "awslogs-group" => heritage.log_group_name,
          "awslogs-region" => district.region,
          "awslogs-stream-prefix" => heritage.name
        }
      }
    }

    before do
      allow(heritage).to receive(:task_role_id) { "task-role" }
      allow(heritage).to receive(:task_execution_role_id) { "task-execution-role" }
    end

    it "returns a task definition for the schedule" do
      expect(subject).to eq({
                              "Family" => "#{heritage.name}-schedule",
                              "TaskRoleArn" => "task-role",
                              "ExecutionRoleArn" => "task-execution-role",
                              "ContainerDefinitions" => [
                                {
                                  "Name" =>  "#{heritage.name}-schedule",
                                  "Cpu" => 128,
                                  "Memory" => 512,
                                  "Essential" => true,
                                  "Image" => heritage.image_path,
                                  "Environment" => [],
                                  "Secrets" => [],
                                  "VolumesFrom" => [
                                    {
                                      "SourceContainer" => "runpack",
                                      "ReadOnly" => true
                                    }
                                  ],
                                  "LogConfiguration" => expected_log_configuration
                                },
                                {
                                  "Name" => "runpack",
                                  "Cpu" => 1,
                                  "Memory" => 16,
                                  "Essential" => false,
                                  "Image" => "quay.io/degica/barcelona-run-pack",
                                  "Environment" => [],
                                  "Secrets" => [],
                                  "LogConfiguration" => expected_log_configuration
                                }
                              ]
                           })
    end
  end
end
