module Barcelona
  module Plugins
    class DatadogPlugin < Base
      def on_container_instance_user_data(_instance, user_data)
        add_files!(user_data)
        user_data.run_commands += [
          agent_command
        ]

        user_data
      end

      private

      def agent_command
        [
          "DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=#{api_key} bash -c",
          '"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)" &&',
          'usermod -a -G docker dd-agent &&',
          'usermod -a -G systemd-journal dd-agent &&',
          'systemctl restart datadog-agent'
        ].flatten.compact.join(" ")
      end

      def api_key
        attributes["api_key"]
      end

      def add_files!(user_data)
        user_data.add_file("/etc/datadog-agent/datadog.yaml", "root:root", "000755", <<~DATADOG_YAML)
          api_key: #{api_key}
          logs_enabled: true
          listeners:
            - name: docker
          config_providers:
            - name: docker
              polling: true
          logs_config:
            container_collect_all: true
          process_config:
            enabled: 'true'
          tags:
            - barcelona:#{district.name}
            - barcelona-dd-agent
            - district:#{district.name}
            - role:app
        DATADOG_YAML

        user_data.add_file("/etc/datadog-agent/conf.d/docker.d/docker_daemon.yaml", "root:root", "000755", <<~YAML)
          init_config:
          instances:
            - url: "unix://var/run/docker.sock"
              new_tag_names: true
        YAML

        user_data.add_file("/etc/datadog-agent/conf.d/journal.d/conf.yaml", "root:root", "000755", <<~YAML)
          logs:
            - type: journald
        YAML
      end
    end
  end
end
