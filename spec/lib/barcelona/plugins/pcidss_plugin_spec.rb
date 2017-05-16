require "rails_helper"
require 'barcelona/plugins/pcidss_plugin'

module Barcelona
  module Plugins
    describe PcidssStack do
      let(:district) do
        create :district, bastion_key_pair: "bastion", plugins_attributes: [
                 {
                   name: 'pcidss',
                   plugin_attributes: {}
                 }
               ]
      end
      let(:stack) { described_class.new(district) }

      before do
        allow_any_instance_of(PcidssBuilder).to receive(:ossec_volume_az) { 'ap-northeast-1a' }
      end

      it "generates a correct stack template" do
        generated = JSON.load stack.target!
        expect(generated["Resources"]["NTPServerLaunchConfiguration"]).to be_present
        expect(generated["Resources"]["NTPServerRole"]).to be_present
        expect(generated["Resources"]["NTPServerProfile"]).to be_present
        expect(generated["Resources"]["NTPServerASG"]).to be_present
        expect(generated["Resources"]["NTPServerSG"]).to be_present
        expect(generated["Resources"]["OSSECManagerVolume"]).to be_present
        expect(generated["Resources"]["OSSECManagerLaunchConfiguration"]).to be_present
        expect(generated["Resources"]["OSSECManagerRole"]).to be_present
        expect(generated["Resources"]["OSSECManagerInstanceProfile"]).to be_present
        expect(generated["Resources"]["OSSECManagerASG"]).to be_present
        expect(generated["Resources"]["OSSECManagerSG"]).to be_present
      end
    end

    describe PcidssPlugin do
      let!(:district) do
        build :district, bastion_key_pair: "bastion", plugins_attributes: [
                 {
                   name: 'pcidss',
                   plugin_attributes: {}
                 }
               ]
      end

      before do
        allow_any_instance_of(PcidssBuilder).to receive(:ossec_volume_az) { 'ap-northeast-1a' }
      end

      it "gets hooked with container_instance_user_data trigger" do
        district.save!
        ci = ContainerInstance.new(district)
        plugin = district.plugins.find_by(name: 'pcidss').plugin
        user_data = YAML.load(Base64.decode64(ci.user_data.build))
        expect(user_data["packages"]).to include(*described_class::SYSTEM_PACKAGES)
        expect(user_data["runcmd"]).to include(*plugin.run_commands)
      end

      it "gets hooked with network_stack_template trigger" do
        district.save!
        template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
        user_data = InstanceUserData.load(template["Resources"]["BastionServer"]["Properties"]["UserData"])
        plugin = district.plugins.find_by(name: 'pcidss').plugin
        expect(user_data.packages).to include(*described_class::SYSTEM_PACKAGES)
        expect(user_data.run_commands).to include(*plugin.run_commands)
      end

      it "gets hooked with created trigger" do
        expect_any_instance_of(PcidssPlugin).to receive_message_chain(:stack_executor, :create_or_update)
        district.save!
      end

      it "gets hooked with updated trigger" do
        district.save!
        plugin = district.plugins.find_by(name: 'pcidss')
        expect_any_instance_of(PcidssPlugin).to receive_message_chain(:stack_executor, :create_or_update)
        plugin.save!
      end

      it "gets hooked with destroyed trigger" do
        district.save!
        plugin = district.plugins.find_by(name: 'pcidss')
        expect_any_instance_of(PcidssPlugin).to receive_message_chain(:stack_executor, :delete)
        plugin.destroy!
      end
    end
  end
end
