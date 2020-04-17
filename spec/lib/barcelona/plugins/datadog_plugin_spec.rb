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
          expect(user_data["runcmd"].last).to eq "DOCKER_CONTENT_TRUST=1 docker run -d --name datadog-agent -h `hostname` -v /var/run/docker.sock:/var/run/docker.sock:ro -v /proc/:/host/proc/:ro -v /cgroup/:/host/sys/fs/cgroup:ro -v /opt/datadog-agent/run:/opt/datadog-agent/run:rw -e DD_API_KEY=abcdef -e DD_LOGS_ENABLED=true -e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true -e DD_AC_EXCLUDE=name:datadog-agent -e DD_TAGS=\"barcelona,barcelona-dd-agent,district:district8\" datadog/agent:latest"
        end
      end
    end
  end
end
