require "rails_helper"

describe CloudFormation::Executor do
  let(:client) { double }
  let(:stack) { CloudFormation::Stack.new("test") }
  let(:executor) { CloudFormation::Executor.new(stack, client) }

  describe "#update" do
    it "creates a change set if true" do
      expect(client).to receive(:create_change_set)
      expect(client).to_not receive(:update_stack)
      executor.update(change_set: true)
    end

    it "updates the stack directly if false" do
      expect(client).to_not receive(:create_change_set)
      expect(client).to receive(:update_stack)
      executor.update(change_set: false)
    end
  end
end
