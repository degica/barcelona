require 'rails_helper'

module Barcelona
  module Plugins
    describe DatadogPlugin do
      context "without proxy plugin" do
        let!(:district) do
          create :district, plugins_attributes: [
            {
              name: 'datadog',
              plugin_attributes: {
                "api_key" => "abcdef"
              }
            }
          ]
        end

        it "gets hooked with container_instance_user_data trigger" do
          ci = ContainerInstance.new(district)
          user_data = YAML.load(Base64.decode64(ci.user_data.build))
          expect(user_data["runcmd"].last).to eq "DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=abcdef bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)\" && usermod -a -G docker dd-agent && usermod -a -G systemd-journal dd-agent && systemctl restart datadog-agent"
        end
      end
    end
  end
end
