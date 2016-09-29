require "rails_helper"

describe ApplyDistrict do
  let(:district) { create :district }

  describe "#create!" do
    it "creates AWS resources" do
      described_class.new(district).create!
    end
  end
end
