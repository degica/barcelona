require "rails_helper"
require 'barcelona/plugins/ossec_client_plugin'

module Barcelona
  module Plugins

    describe OssecClientPlugin do
      let!(:district) do
        build :district, bastion_key_pair: "bastion", plugins_attributes: [
                 {
                   name: 'ossec_client',
                   plugin_attributes: {
                     "server_hostname": 'ossec-manager.test.local'
                   }
                 }
               ]
      end

      shared_examples_for('ossec client') do
        it "installs wazuh client" do
          expect(user_data["packages"]).to include('wazuh-agent')
        end

        it "configures wazuh client propperly" do
          expect(user_data["runcmd"]).to include("/var/ossec/bin/agent-auth -m ossec-manager.test.local")
          expect(user_data["runcmd"]).to include("/var/ossec/bin/ossec-control restart")
        end
      end

      context "when hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        let(:user_data) {YAML.load(Base64.decode64(ci.user_data.build)) } 

        it_behaves_like('ossec client')
      end

      context "when hooked with network_stack_template trigger" do
        before do
          district.save!
        end
        let(:user_data) do
          template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
          user_data_base64 = template["Resources"]["BastionLaunchConfiguration"]["Properties"]["UserData"]
          YAML.load(Base64.decode64(user_data_base64))
        end

        it_behaves_like('ossec client')
      end
    end
  end
end
