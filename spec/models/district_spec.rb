require 'rails_helper'

describe District do
  let(:district) { create(:district) }
  let(:ec2_mock) { double }
  let(:ecs_mock) { double }
  let(:s3_mock)  { double }


  describe "#validations" do
    let(:district) { build :district }
    before do
      allow(Rails).to receive_message_chain(:env, :test?) {
        false
      }
    end
    context "when aws keys are nil" do
      let(:district) { build :district }
      it { expect(district).to_not be_valid }
    end
    context "when aws keys are present" do
      let(:district) { build :district,
                             aws_access_key_id: "AWS_ACCESS_KEY_ID",
                             aws_secret_access_key: "AWS_SECRET_ACCESS_KEY" }
      it { expect(district).to be_valid }
    end
  end

  describe "callbacks" do
    it "assigns default users" do
      user1 = create :user
      user2 = create :user
      district1 = District.create!(name: 'name')
      district1.reload
      expect(district1.users).to include(user1)
      expect(district1.users).to include(user2)
    end

    it "deletes all associated plugins" do
      district.save!
      plugin = district.plugins.create(name: 'ntp', plugin_attributes: {ntp_hosts: ["10.0.0.1"]})
      expect(plugin).to_not receive(:save_district)
      district.destroy!
    end
  end

  describe "#subnets" do
    before do
      allow(district).to receive_message_chain(:aws, :ec2) { ec2_mock }
      allow(district).to receive_message_chain(:aws, :ecs) { ecs_mock }
      allow(district).to receive_message_chain(:aws, :s3)  { s3_mock }
    end

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
    before do
      allow(district).to receive_message_chain(:aws, :ec2) { ec2_mock }
      allow(district).to receive_message_chain(:aws, :ecs) { ecs_mock }
      allow(district).to receive_message_chain(:aws, :s3)  { s3_mock }
    end

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
                double(
                  instance_id: 'ec2_instance_id',
                  private_ip_address: "10.0.0.1",
                  launch_time: 1.day.ago,
                  instance_type: 't2.micro'
                )
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
end
