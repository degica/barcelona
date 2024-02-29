module Barcelona
  module Plugins
    class DatadogPlugin < Base
      # This plugin must be the last of the instalation order
      # Usage sample: 
      # bcn district put-plugin -a api_key=8e53.... -a hook_priority=10 ec-staging datadog

      def on_container_instance_user_data(_instance, user_data)
        add_files!(user_data)
        user_data.run_commands += [
          agent_command
        ]

        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        add_files!(user_data, has_docker: false)
        user_data.run_commands += [
          agent_command(has_docker: false)
        ]
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      private

      def on_heritage_task_definition(_heritage, task_definition)
        # disable awslogs, but make sure logs do not fill up disk
        task_definition.merge(
          log_configuration: {
            log_driver: "json-file",
            options: {
              "max-size" => "1m",
              "tag" => "{{.FullID}}_#{task_definition[:name]}"
            }
          }
        )
      end

      def agent_command(has_docker: true)
        [
          "DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=#{api_key} bash -c",
          '"$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)" &&',
          has_docker ? 'usermod -a -G docker dd-agent &&' : '',
          'usermod -a -G systemd-journal dd-agent &&',
          'systemctl restart datadog-agent'
        ].flatten.compact.join(" ")
      end

      def api_key
        attributes["api_key"]
      end

      def add_files!(user_data, has_docker: true)
        # this seems to be added to the bastion instance as well. "role:app" should probably be "role:bastion" to be accurate
        if has_docker
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
            runtime_security_config:
              enabled: true
            compliance_config:
              enabled: true
            sbom:
              enabled: true
              container_image:
                enabled: true
              host:
                enabled: true
            container_image:
              enabled: true
            tags:
              - barcelona:#{district.name}
              - barcelona-dd-agent
              - district:#{district.name}
              - role:app
          DATADOG_YAML
        else
          user_data.add_file("/etc/datadog-agent/datadog.yaml", "root:root", "000755", <<~DATADOG_YAML)
            api_key: #{api_key}
            logs_enabled: true
            listeners:
              - name: docker
            config_providers:
              - name: docker
                polling: true
            logs_config:
              container_collect_all: false
            process_config:
              enabled: 'true'
            runtime_security_config:
              enabled: true
            compliance_config:
              enabled: true
            sbom:
              enabled: true
              container_image:
                enabled: false
              host:
                enabled: true
            container_image:
              enabled: false
            tags:
              - barcelona:#{district.name}
              - barcelona-dd-agent
              - district:#{district.name}
              - role:app
          DATADOG_YAML
        end

        user_data.add_file("/etc/datadog-agent/system-probe.yaml", "root:root", "000755", <<~YAML)
          runtime_security_config:
            enabled: true
        YAML

        user_data.add_file("/etc/datadog-agent/security-agent.yaml", "root:root", "000755", <<~YAML)
          runtime_security_config:
            enabled: true
          compliance_config:
            enabled: true
            host_benchmarks:
              enabled: true
        YAML

        if has_docker
          user_data.add_file("/etc/datadog-agent/conf.d/docker.d/docker_daemon.yaml", "root:root", "000755", <<~YAML)
            init_config:
            instances:
              - url: "unix://var/run/docker.sock"
                new_tag_names: true
          YAML
        end

        user_data.add_file("/etc/datadog-agent/conf.d/journal.d/conf.yaml", "root:root", "000755", <<~YAML)
          logs:
            - type: journald
        YAML
      end
    end
  end
end
