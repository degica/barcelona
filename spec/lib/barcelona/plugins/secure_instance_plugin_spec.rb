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

      shared_examples_for('pcidss tools') do
        it "installs required packages for pcidss" do
          expect(user_data["runcmd"]).to include(/yum install -y clamav clamav-update tmpwatch fail2ban/)
        end

        it "installs and configures fail2ban" do
          jail_local = user_data['write_files'].find do |f|
            f['path'] == '/etc/fail2ban/jail.local'
          end

          expect(user_data["runcmd"]).to include("systemctl restart fail2ban")
          expect(jail_local['content']).to include %q{[sshd]}
          expect(jail_local['content']).to include %q{action = iptables[name=SSH, port=ssh, protocol=tcp]}
        end
      end

      context "when hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        let(:user_data) {YAML.load(Base64.decode64(ci.user_data.build)) } 
        it_behaves_like('pcidss tools')

        it "does not reboot the instance" do
          expect(user_data["bootcmd"]).to be_nil
        end

        it "installs tcp_wrappers" do
          expect(user_data["packages"]).to include('tcp_wrappers') # CIS 3.3.1
        end
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

        it_behaves_like('pcidss tools')

        it "applies security update" do
          # the first command must be the checking of security update
          expect(user_data["runcmd"][1]).to eq('if [ -f /root/.security_update_applied ]')
          expect(user_data["runcmd"]).to include(/yum update -y --security/)
          expect(user_data["runcmd"]).to include(/reboot/)
          expect(user_data["cloud_final_modules"]).to eq [['scripts-user', 'always']]
        end
      end
    end
  end
end
