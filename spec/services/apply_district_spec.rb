require "rails_helper"

describe ApplyDistrict do
  let(:district) { build :district }

  describe "#create!" do
    it "creates AWS resources" do
      described_class.new(district).create!
    end
  end

  describe "#destroy" do
    it "deletes AWS resources" do
      district.save!
      described_class.new(district).destroy!
    end
  end
end
