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
          expect(user_data["bootcmd"]).to include(/yum update -y --security/)
          expect(user_data["bootcmd"]).to include(/reboot/)
        end

        it "installs required packages for pcidss" do
          expect(user_data["runcmd"]).to include(/yum install -y clamav clamav-update tmpwatch fail2ban/)
        end

        it "configure auditd as recommended in CIS" do
          audit_rules = user_data['write_files'].find do |f|
            f['path'] == '/etc/audit/rules.d/audit.rules'
          end

          expect(audit_rules["content"]).to match(%r[-w /var/log/lastlog -p wa -k logins])
        end
      end

      context "when hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        let(:user_data) {YAML.load(Base64.decode64(ci.user_data.build)) } 
        it_behaves_like('secure instance')
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
        it_behaves_like('secure instance')
      end
    end
  end
end
