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

  describe "#ecs_config" do
    let(:name) { :private }
    it { expect(section.send(:ecs_config)).to include "ECS_CLUSTER=#{section.cluster_name}" }
    it { expect(section.send(:ecs_config)).to_not include "ECS_ENGINE_AUTH_DATA" }
    it { expect(section.send(:ecs_config)).to_not include "ECS_ENGINE_AUTH_TYPE" }
    it { expect(section.send(:ecs_config)).to include 'ECS_AVAILABLE_LOGGING_DRIVERS=["json-file", "syslog", "fluentd"]' }
    it { expect(section.send(:ecs_config)).to include "ECS_RESERVED_MEMORY=128" }
    context "when dockercfg exists" do
      before do
        district.dockercfg = {auth: "abcdef"}
      end
      it { expect(section.send(:ecs_config)).to_not include 'ECS_ENGINE_AUTH_DATA={"auth": "abcdef"}' }
    end
  end
end
