require 'rails_helper'

describe Plugin do
  let(:district) { create(:district) }
  let(:plugin) { Plugin.new(name: name, district: district) }

  describe "validations" do
    context "when plugin class doesnt exist" do
      let(:name) { "wrong" }
      it { expect(plugin).to_not be_valid }
    end

    context "when plugin class exists" do
      let(:name) { "logentries" }
      it { expect(plugin).to be_valid }
    end
  end

  describe "#hook" do
    context "when plugin class doesnt exist" do
      let(:name) { "wrong" }
      it "calls plugin method" do
        expect_any_instance_of(Barcelona::Plugins::LogentriesPlugin).to_not receive(:hook)
        expect(plugin.hook(:trigger, nil, "argument")).to eq "argument"
      end
    end

    context "when plugin class exists" do
      let(:name) { "logentries" }
      it "calls plugin method" do
        expect_any_instance_of(Barcelona::Plugins::LogentriesPlugin).to receive(:hook)
        plugin.hook(:trigger, nil)
      end
    end
  end
end
