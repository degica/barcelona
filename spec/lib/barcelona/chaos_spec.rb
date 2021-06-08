require "rails_helper"

describe Barcelona::Chaos do
  describe "#run" do
    let(:district) { create :district }
    let(:asg_mock) { double }
    let(:chaos) { described_class.new(district, 1) }

    before do
      allow_any_instance_of(AwsAccessor).to receive(:autoscaling) { asg_mock }
    end

    context "when the district has only active instances" do
      before do
        expect(district).to receive(:container_instances) do
          [
            {status: 'ACTIVE', ec2_instance_id: 'i-11111111', launch_time: 1.day.ago},
            {status: 'ACTIVE', ec2_instance_id: 'i-22222222', launch_time: 2.days.ago}
          ]
        end
      end

      it "makes a terminate request for the instance" do
        expect(asg_mock).to receive(:terminate_instance_in_auto_scaling_group).with(
          instance_id: 'i-22222222',
          should_decrement_desired_capacity: false
        )
        expect(asg_mock).to_not receive(:terminate_instance_in_auto_scaling_group).with(
          instance_id: 'i-11111111',
          should_decrement_desired_capacity: false
        )
        chaos.run
      end
    end

    context "when the district has non-active instance" do
      before do
        expect(district).to receive(:container_instances) do
          [
            {status: 'ACTIVE', ec2_instance_id: 'i-11111111', launch_time: 1.day.ago},
            {status: 'DRAINING', ec2_instance_id: 'i-11111111', launch_time: 1.day.ago}
          ]
        end
      end

      it "does not make a terminate request for the instance" do
        expect(asg_mock).to_not receive(:terminate_instance_in_auto_scaling_group)
        chaos.run
      end
    end
  end
end
