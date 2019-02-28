require "rails_helper"

describe ReviewGroup do
  let(:endpoint) { create :endpoint }

  describe "#save" do
    it "works" do
      group = ReviewGroup.new(endpoint: endpoint, name: "group-name", base_domain: "reviewapps.degica.com")
      expect(group.cf_executor).to receive(:create_or_update)
      expect{group.save!}.to_not raise_error
    end
  end

  describe "#destroy" do
    it "works" do
      group = ReviewGroup.create!(endpoint: endpoint, name: "group-name", base_domain: "reviewapps.degica.com")
      expect(group.cf_executor).to receive(:delete)
      expect{group.destroy!}.to_not raise_error
    end
  end
end

describe ReviewGroup::Stack do
  let(:review_group) { build :review_group }
  let(:stack) { described_class.new(review_group) }

  describe "#target!" do
    it "generates a correct stack template" do
      generated = JSON.load stack.target!
      expect(generated["Resources"]["TaskRole"]).to be_present
    end
  end
end
