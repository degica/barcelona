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
                             aws_secret_access_key: "AWS_SECRET_ACCESS_KEY"
      }
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

  describe '#services' do
    it 'finds the services for the current district' do
      d1 = create :district, name: 'd1'
      d1h1 = create :heritage, district: d1, name: 'd1h1'
      d1h1s1 = create :service, heritage: d1h1, name: 'd1h1s1'
      d1h1s2 = create :service, heritage: d1h1, name: 'd1h1s2'
      d1h1s3 = create :service, heritage: d1h1, name: 'd1h1s3'

      d1h2 = create :heritage, district: d1, name: 'd1h2'
      d1h2s1 = create :service, heritage: d1h2, name: 'd1h2s1'
      d1h2s2 = create :service, heritage: d1h2, name: 'd1h2s2'

      d2 = create :district, name: 'd2'
      d2h1 = create :heritage, district: d2, name: 'd2h1'
      d2h1s1 = create :service, heritage: d2h1, name: 'd2h1s1'
      d2h1s2 = create :service, heritage: d2h1, name: 'd2h1s2'

      d2h2 = create :heritage, district: d2, name: 'd2h2'
      d2h2s1 = create :service, heritage: d2h2, name: 'd2h2s1'
      d2h2s2 = create :service, heritage: d2h2, name: 'd2h2s2'

      expect(d1.services).to eq [d1h1s1, d1h1s2, d1h1s3, d1h2s1, d1h2s2]
      expect(d2.services).to eq [d2h1s1, d2h1s2, d2h2s1, d2h2s2]
    end
  end

  describe '#service_deployments' do
    it 'finds the service deployments for the current district' do
      d1 = create :district, name: 'd1'
      d1h1 = create :heritage, district: d1, name: 'd1h1'
      d1h1s1 = create :service, heritage: d1h1, name: 'd1h1s1'

      dep1 = create :service_deployment, service: d1h1s1

      d1h1s2 = create :service, heritage: d1h1, name: 'd1h1s2'
      d1h1s3 = create :service, heritage: d1h1, name: 'd1h1s3'

      dep2 = create :service_deployment, service: d1h1s3

      d1h2 = create :heritage, district: d1, name: 'd1h2'
      d1h2s1 = create :service, heritage: d1h2, name: 'd1h2s1'
      d1h2s2 = create :service, heritage: d1h2, name: 'd1h2s2'

      d2 = create :district, name: 'd2'
      d2h1 = create :heritage, district: d2, name: 'd2h1'
      d2h1s1 = create :service, heritage: d2h1, name: 'd2h1s1'
      d2h1s2 = create :service, heritage: d2h1, name: 'd2h1s2'

      d2h2 = create :heritage, district: d2, name: 'd2h2'
      d2h2s1 = create :service, heritage: d2h2, name: 'd2h2s1'
      d2h2s2 = create :service, heritage: d2h2, name: 'd2h2s2'

      expect(d1.service_deployments).to eq [dep1, dep2]
    end
  end

end
