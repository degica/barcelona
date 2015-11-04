require 'rails_helper'

describe ElasticIp do
  let(:district) { create(:district) }
  let(:ec2_mock) { double }
  let(:eip) { district.elastic_ips.create(allocation_id: 'allocation_id') }

  describe ".available" do
    it { expect(ElasticIp.available(district)).to_not be_nil }
  end

  describe "#associate" do
    it { expect{eip.associate("instance_id")}.to_not raise_error }
  end
end
