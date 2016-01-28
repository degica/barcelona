require 'rails_helper'

module Barcelona
  module Plugins
    describe NtpPlugin do
      let!(:district) do
        create :district, plugins_attributes: [
          {
            name: 'ntp',
            plugin_attributes: {ntp_hosts: ["10.0.0.1"]}
          }
        ]
      end

      it "gets hooked with container_instance_user_data trigger" do
        ci = ContainerInstance.new(district, instance_type: 't2.micro')
        user_data = YAML.load(Base64.decode64(ci.instance_user_data))
        expect(user_data['bootcmd']).to include "sed -i '/^server /s/^/#/' /etc/ntp.conf"
        expect(user_data['bootcmd']).to include "echo server 10.0.0.1 iburst >> /etc/ntp.conf"
        expect(user_data['bootcmd']).to include "service ntpd restart"
      end
    end
  end
end
