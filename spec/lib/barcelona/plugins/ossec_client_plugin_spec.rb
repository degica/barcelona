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

      context "gets hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        subject {YAML.load(Base64.decode64(ci.user_data.build)) } 

        it "installs wazuh client" do
          expect(subject["packages"]).to include('wazuh-agent')
        end

        it "configures wazuh client propperly" do
          ossec_conf = subject['write_files'].find do |f|
            f['path'] == '/var/ossec/etc/ossec.conf'
          end
          expect(ossec_conf['content']).to match %r[<server-hostname>ossec-manager.test.local</server-hostname>]
          expect(subject["runcmd"]).to include("/var/ossec/bin/agent-auth -m ossec-manager.test.local")
          expect(subject["runcmd"]).to include("/var/ossec/bin/ossec-control restart")
        end
      end
    end
  end
end
