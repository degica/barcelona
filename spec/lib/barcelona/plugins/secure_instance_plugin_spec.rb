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

      Packages = %w(clamav clamav-update tmpwatch fail2ban)
      context "gets hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        subject {YAML.load(Base64.decode64(ci.user_data.build)) } 

        it "applies security update" do
          expect(subject["bootcmd"]).to include("yum update -y --security")
          expect(subject["bootcmd"]).to include("reboot")
        end

        it "installs required packages" do
          Packages.each do |pkg|
            expect(subject["packages"]).to include(pkg)
          end
        end
      end
    end
  end
end
