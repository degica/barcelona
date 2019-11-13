require "rails_helper"
require 'barcelona/plugins/secure_instance_plugin'

module Barcelona
  module Plugins

    describe SecureInstancePlugin do
      let!(:district) do
        build :district, bastion_key_pair: "bastion", plugins_attributes: [
                 {
                   name: 'secure_instance',
                   plugin_attributes: {
                   }
                 }
               ]
      end

      shared_examples_for('secure instance') do
        it "applies security update" do
          expect(user_data["bootcmd"]).to include("yum update -y --security")
          expect(user_data["bootcmd"]).to include("reboot")
        end

        it "installs required packages" do
          %w(clamav clamav-update tmpwatch fail2ban).each do |pkg|
            expect(user_data["packages"]).to include(pkg)
          end
        end
      end

      context "gets hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        let(:user_data) {YAML.load(Base64.decode64(ci.user_data.build)) } 
        it_behaves_like('secure instance')
      end

      context "gets hooked with network_stack_template trigger" do
        before do
          district.save!
        end

        let(:user_data) do
          template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
          user_data_base64 = template["Resources"]["BastionLaunchConfiguration"]["Properties"]["UserData"]
          YAML.load(Base64.decode64(user_data_base64))
        end
        it_behaves_like('secure instance')
      end
    end
  end
end
