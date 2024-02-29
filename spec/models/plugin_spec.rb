require 'rails_helper'

describe Plugin do
  let(:plugin) { Plugin.new(name: name) }

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

  describe "#hook_priority" do
    context "when not specified" do
      let(:plugin) { Plugin.new(name: 'test') }
      it "should be zero" do
        expect(plugin.hook_priority).to eq(0)
      end
    end

    context "when specified" do
      let(:plugin) { Plugin.new(name: 'test', plugin_attributes:{ "api_key": 'abcdefg', hook_priority: '10'}) }
      it "should be the specified value" do
        expect(plugin.hook_priority).to eq(10)
      end
    end
  end
end
