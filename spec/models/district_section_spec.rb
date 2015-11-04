require 'rails_helper'

describe DistrictSection do
  let(:district) { build(:district) }
  let(:section) { described_class.new(name, district) }

  describe "#cluster_name" do
    context "when name is public" do
      let(:name) { :public }
      it { expect(section.cluster_name).to eq "#{district.name}-public" }
    end

    context "when name is private" do
      let(:name) { :private }
      it { expect(section.cluster_name).to eq district.name }
    end
  end
end
