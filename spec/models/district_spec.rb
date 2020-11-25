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

    context "when aws keys and role are nil" do
      let(:district) { build :district, aws_role: nil, aws_access_key_id: nil, aws_secret_access_key: nil }
      it { expect(district).to_not be_valid }
    end

    context "when role is present" do
      let(:district) { build :district, aws_role: "role", aws_access_key_id: nil, aws_secret_access_key: nil }
      it { expect(district).to be_valid }
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
      district.plugins.create(name: 'ntp', plugin_attributes: {ntp_hosts: ["10.0.0.1"]})
      expect(district).to_not receive(:save!)
      district.destroy!
      expect(Plugin.count).to be_zero
    end
  end

  describe "#subnets" do
    before do
      allow(district.aws).to receive(:ec2) { ec2_mock }
      allow(district.aws).to receive(:ecs) { ecs_mock }
      allow(district.aws).to receive(:s3)  { s3_mock }
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
                  instance_type: 't2.small'
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

  describe "#publish_sns" do
    it "publishes message to the notification topic" do
      expect(district.aws.sns).to receive(:publish)
      allow(district).to receive(:notification_topic) { "notification-topic-arn" }
      district.publish_sns("message")
    end
  end

  describe '#instances_recommended' do
    it 'gives the maximum from cpu and memory requirements' do
      allow(district).to receive(:instance_count_demanded).with(:cpu) { 100 }
      allow(district).to receive(:instance_count_demanded).with(:memory) { 10 }

      expect(district.send(:instances_recommended)).to eq 100
    end
  end

  describe '#instance_count_demanded' do
    before do
      # set some constants
      allow(district).to receive(:container_instances) { [1] }
      allow(district).to receive(:total_registered) { 1000 }
    end

    it 'gives 1 more server than required if we have only 1 service type with exact occupancy' do
      allow(district).to receive(:demand_structure) { { 1000 => 3 } }

      expect(district.send(:instance_count_demanded, :something)).to eq 4
    end

    it 'gives one more server required if we have 1 service type with less than half occupancy' do
      allow(district).to receive(:demand_structure) { { 400 => 3 } }

      expect(district.send(:instance_count_demanded, :something)).to eq 3
    end

    it 'gives exactly the number of servers required if we have 1 service type with more than half occupancy' do
      allow(district).to receive(:demand_structure) { { 600 => 3 } }

      expect(district.send(:instance_count_demanded, :something)).to eq 3
    end

    it 'gives two more servers than required if we have 1 service type with less than half occupancy and a minor type' do
      allow(district).to receive(:demand_structure) { { 400 => 3, 100 => 3 } }

      expect(district.send(:instance_count_demanded, :something)).to eq 5
    end

    it 'gives two more servers than required if we have 1 service type with more than half occupancy and a minor type' do
      allow(district).to receive(:demand_structure) { { 600 => 3, 100 => 3 } }

      expect(district.send(:instance_count_demanded, :something)).to eq 5
    end

  end
end
