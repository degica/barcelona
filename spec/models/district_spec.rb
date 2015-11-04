require 'rails_helper'

describe District do
  let(:district) { create(:district) }
  let(:ec2_mock) { double }
  let(:ecs_mock) { double }
  let(:s3_mock)  { double }

  before do
    allow(district).to receive_message_chain(:aws, :ec2) { ec2_mock }
    allow(district).to receive_message_chain(:aws, :ecs) { ecs_mock }
    allow(district).to receive_message_chain(:aws, :s3)  { s3_mock }
  end

  describe "#subnets" do
    it "returns private subnets" do
      expect(ec2_mock).to receive(:describe_subnets).with(
                            filters: [
                              {name: "vpc-id", values: [district.vpc_id]},
                              {name: "tag:Network", values: ["Private"]}
                            ]) do
        double(subnets: [double(subnet_id: "subnet_id")])
      end
      expect(district.subnets("Private").count).to eq 1
    end

    it "returns public subnets" do
      expect(ec2_mock).to receive(:describe_subnets).with(
                            filters: [
                              {name: "vpc-id", values: [district.vpc_id]},
                              {name: "tag:Network", values: ["Public"]}
                            ]) do
        double(subnets: [double(subnet_id: "subnet_id")])
      end
      expect(district.subnets("Public").count).to eq 1
    end
  end

  describe "#container_instances" do
    it "returns container instances and ec2 instances information" do
      expect(ecs_mock).to receive(:list_container_instances) do
        double(
          container_instance_arns: ["arn"]
        )
      end
      expect(ecs_mock).to receive(:describe_container_instances).with(
                            cluster: district.name,
                            container_instances: ["arn"]
                          ) do
        double(
          container_instances: [
            double(
              status: "registered",
              ec2_instance_id: "ec2_instance_id",
              container_instance_arn: "arn",
              remaining_resources: [],
              registered_resources: [],
              running_tasks_count: 0,
              pending_tasks_count: 0
            )
          ]
        )
      end

      expect(ec2_mock).to receive(:describe_instances) do
        double(
          reservations: [
            double(
              instances: [
                double(instance_id: 'ec2_instance_id', private_ip_address: "10.0.0.1")
              ]
            )
          ]
        )
      end

      result = district.container_instances
      expect(result).to be_a Array
      expect(result.count).to eq 1
      expect(result.first).to have_key :container_instance_arn
      expect(result.first).to have_key :ec2_instance_id
      expect(result.first).to have_key :private_ip_address
    end
  end

  describe "#launch_instances" do
    subject { district.launch_instances(count: 1, instance_type: 't2.micro') }

    before do
      expect(ec2_mock).to receive(:describe_subnets).with(
                            filters: [
                              {name: "vpc-id", values: [district.vpc_id]},
                              {name: "tag:Network", values: ["Private"]}
                            ]) do
        double(subnets: [double(subnet_id: "subnet_id")])
      end
    end

    it "launches EC2 instance" do
      expect(ec2_mock).to receive(:run_instances).with(
                            image_id: instance_of(String),
                            min_count: 1,
                            max_count: 1,
                            user_data: instance_of(String),
                            instance_type: "t2.micro",
                            network_interfaces: [
                              {
                                groups: [district.instance_security_group],
                                subnet_id: "subnet_id",
                                device_index: 0,
                                associate_public_ip_address: false
                              }
                            ],
                            iam_instance_profile: {
                              name: district.ecs_instance_role
                            }
                          )
      subject
    end
  end
end
