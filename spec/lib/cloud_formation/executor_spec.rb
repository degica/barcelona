require "rails_helper"

describe CloudFormation::Executor do
  let(:client) { double('cloudformation') }
  let(:s3) { double('s3') }
  let(:aws) { double('aws', cloudformation: client, s3: s3) }
  let(:district) { double('district', aws: aws, s3_bucket_name: 'bucketname') }
  let(:stack) { CloudFormation::Stack.new("test") }
  let(:executor) { CloudFormation::Executor.new(stack, district) }

  describe "#update" do
    it "creates a change set if true" do
      expect(s3).to receive(:put_object)
      expect(s3).to receive(:wait_until).with(:object_exists, anything, anything)
      expect(client).to receive(:create_change_set)
      expect(client).to_not receive(:update_stack)
      executor.update(change_set: true)
    end

    it "updates the stack directly if false" do
      expect(s3).to receive(:put_object)
      expect(s3).to receive(:wait_until).with(:object_exists, anything, anything)
      expect(client).to_not receive(:create_change_set)
      expect(client).to receive(:update_stack)
      executor.update(change_set: false)
    end

    it "passes on any failures from s3 wait" do
      expect(s3).to receive(:put_object)
      expect(s3).to receive(:wait_until).with(:object_exists, anything, anything) do
        raise Aws::Waiters::Errors::WaiterFailed
      end
      expect(client).to_not receive(:create_change_set)
      expect(client).to_not receive(:update_stack)
      expect(Rails.logger).to receive(:warn).with("Upload failed: Aws::Waiters::Errors::WaiterFailed")
      expect { executor.update(change_set: true) }.to raise_error Aws::Waiters::Errors::WaiterFailed
    end

    it "has template name that is not time dependent (regression)" do
      expect(executor).to receive(:stack) { double(name: 'foobar') }
      travel_to DateTime.new(2017, 7, 7)
      expect(executor.template_name).to eq "stack_templates/foobar/2017-07-07-000000.template"
      travel_back
      travel_to DateTime.new(2019, 9, 9)
      expect(executor.template_name).to eq "stack_templates/foobar/2017-07-07-000000.template"
      travel_back
    end
  end
end
