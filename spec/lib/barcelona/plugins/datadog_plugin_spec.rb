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

        it "installs system-probe config file" do
          system_probe_config = user_data['write_files'].find do |f|
            f['path'] == '/etc/datadog-agent/system-probe.yaml'
          end
          system_probe_config_hash = YAML.load(system_probe_config['content'])
          expect(system_probe_config_hash['runtime_security_config']['enabled']).to eq(true)
        end

        it "installs security-agent config file" do
          security_agent_config = user_data['write_files'].find do |f|
            f['path'] == '/etc/datadog-agent/security-agent.yaml'
          end
          security_agent_config_hash = YAML.load(security_agent_config['content'])
          expect(security_agent_config_hash['runtime_security_config']['enabled']).to eq(true)
          expect(security_agent_config_hash['compliance_config']['enabled']).to eq(true)
          expect(security_agent_config_hash['compliance_config']['host_benchmarks']['enabled']).to eq(true)
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

          it "adds datadog agent instalation to bastion servers" do
            expect(user_data["runcmd"].last).to eq "DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=abcdef bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)\" &&  usermod -a -G systemd-journal dd-agent && systemctl restart datadog-agent"
          end

          it "installs agent config file to bastion servers" do
            agent_config = user_data['write_files'].find do |f|
              f['path'] == '/etc/datadog-agent/datadog.yaml'
            end
            agent_config_hash = YAML.load(agent_config['content'])
            expect(agent_config_hash['api_key']).to eq(api_key)
            expect(agent_config_hash['logs_enabled']).to eq(true)
            expect(agent_config_hash['runtime_security_config']['enabled']).to eq(true)
          end

          it "installs system-probe config file to bastion servers" do
            system_probe_config = user_data['write_files'].find do |f|
              f['path'] == '/etc/datadog-agent/system-probe.yaml'
            end
            system_probe_config_hash = YAML.load(system_probe_config['content'])
            expect(system_probe_config_hash['runtime_security_config']['enabled']).to eq(true)
          end

          it "installs security-agent config file to bastion servers" do
            security_agent_config = user_data['write_files'].find do |f|
              f['path'] == '/etc/datadog-agent/security-agent.yaml'
            end
            security_agent_config_hash = YAML.load(security_agent_config['content'])
            expect(security_agent_config_hash['runtime_security_config']['enabled']).to eq(true)
            expect(security_agent_config_hash['compliance_config']['enabled']).to eq(true)
            expect(security_agent_config_hash['compliance_config']['host_benchmarks']['enabled']).to eq(true)
          end
        end
      end
    end
  end
end
