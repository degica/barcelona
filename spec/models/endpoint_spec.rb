require 'rails_helper'

describe Endpoint do
  let(:endpoint) { build :endpoint }

  describe "callbacks" do
    it "creates or updates cloudformation stack" do
      expect_any_instance_of(CloudFormation::Executor).to receive(:create_or_update)
      endpoint.save!
    end

    it "deltes cloudformation stack" do
      endpoint.save!
      expect_any_instance_of(CloudFormation::Executor).to receive(:delete)
      endpoint.destroy!
    end
  end
end

describe Endpoint::Stack do
  let(:endpoint) { build :endpoint }
  let(:stack) { described_class.new(endpoint) }
  it "generates endpoint stack" do
    generated = JSON.load(stack.target!)
    expect(generated["Resources"]["LB"]).to be_present
    expect(generated["Resources"]["LBListenerHTTP"]).to be_present
    expect(generated["Resources"]["LBListenerHTTPS"]).to be_present
    expect(generated["Resources"]["DefaultTargetGroup"]).to be_present
    expect(generated["Resources"]["RecordSet"]).to be_present
  end

  context "when an endpoint doesn't have a certificate" do
    let(:endpoint) { build :endpoint, certificate_id: nil }
    it "generates endpoint stack" do
      generated = JSON.load(stack.target!)
      expect(generated["Resources"]["LB"]).to be_present
      expect(generated["Resources"]["LBListenerHTTP"]).to be_present
      expect(generated["Resources"]["LBListenerHTTPS"]).to_not be_present
      expect(generated["Resources"]["RecordSet"]).to be_present
    end
  end
end
