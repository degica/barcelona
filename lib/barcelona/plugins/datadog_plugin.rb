module Barcelona
  module Plugins
    class DatadogPlugin < Base
      def on_container_instance_user_data(_instance, user_data)
        user_data.run_commands += [
          agent_command
        ]

        user_data
      end

      private

      def agent_command
        ["docker", "run", "-d",
         "--name", "dd-agent",
         "-h", "`hostname`",
         "-v", "/var/run/docker.sock:/var/run/docker.sock",
         "-v", "/proc/:/host/proc/:ro",
         "-v", "/sys/fs/cgroup/:/host/sys/fs/cgroup:ro",
         "-e", "API_KEY=#{api_key}",
         proxy_env,
         tags,
         "datadog/docker-dd-agent:latest"
        ].flatten.compact.join(" ")
      end

      def proxy_env
        if proxy_plugin.present?
          [
            "-e", "PROXY_HOST=#{proxy_plugin.proxy_host}",
            "-e", "PROXY_PORT=#{proxy_plugin.proxy_port}"
          ]
        end
      end

      def tags
        "-e TAGS=\"barcelona,district:#{district.name}\""
      end

      def proxy_plugin
        @proxy_plugin ||= district.plugins.find_by(name: "proxy").try(:plugin)
      end

      def api_key
        attributes[:api_key]
      end
    end
  end
end
