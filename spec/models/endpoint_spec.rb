require 'rails_helper'

describe Endpoint do
  let(:endpoint) { build :endpoint }

  describe "callbacks" do
    it "creates cloudformation stack" do
      expect_any_instance_of(CloudFormation::Executor).to receive(:create)
      endpoint.save!
    end

    it "updates cloudformation stack" do
      endpoint.save!
      expect_any_instance_of(CloudFormation::Executor).to receive(:update)
      endpoint.save!
    end

    it "deltes cloudformation stack" do
      endpoint.save!
      expect_any_instance_of(CloudFormation::Executor).to receive(:delete)
      endpoint.destroy!
    end
  end

  describe "#alb_ssl_policy" do
    it "is set to default value" do
      expect(endpoint.alb_ssl_policy).to eq "ELBSecurityPolicy-2016-08"
    end

    it "is set to 2017-01" do
      endpoint.ssl_policy = 'modern'
      expect(endpoint.alb_ssl_policy).to eq "ELBSecurityPolicy-TLS-1-2-2017-01"
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
