require 'rails_helper'

module Barcelona
  module Plugins
    describe DatadogPlugin do
      context "without proxy plugin" do
        let(:api_key) { 'abcdef'}
        let!(:district) do
          create :district, plugins_attributes: [
            {
              name: 'datadog',
              plugin_attributes: {
                "api_key" => api_key
              }
            }
          ]
        end
        let (:user_data) do
          ci = ContainerInstance.new(district)
          YAML.load(Base64.decode64(ci.user_data.build))
        end

        it "gets hooked with container_instance_user_data trigger" do
          expect(user_data["runcmd"].last).to eq "DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=abcdef bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)\" && usermod -a -G docker dd-agent && usermod -a -G systemd-journal dd-agent && systemctl restart datadog-agent"
        end

        it "installs agent config file" do
          agent_config = user_data['write_files'].find do |f|
            f['path'] == '/etc/datadog-agent/datadog.yaml'
          end
          agent_config_hash = YAML.load(agent_config['content'])
          expect(agent_config_hash['api_key']).to eq(api_key)
          expect(agent_config_hash['logs_enabled']).to eq(true)
          expect(agent_config_hash['runtime_security_config']['enabled']).to eq(true)
        end
      end
    end
  end
end
