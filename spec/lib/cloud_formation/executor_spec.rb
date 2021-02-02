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

    it "creates a change set if true" do
      expect(s3).to receive(:put_object)
      expect(s3).to receive(:wait_until).with(:object_exists, anything, anything) do
        raise Aws::Waiters::Errors::WaiterFailed
      end
      expect(client).to_not receive(:create_change_set)
      expect(client).to_not receive(:update_stack)
      expect(Rails.logger).to receive(:warn).with("Upload failed: Aws::Waiters::Errors::WaiterFailed")
      expect { executor.update(change_set: true) }.to raise_error Aws::Waiters::Errors::WaiterFailed
    end
  end
end
