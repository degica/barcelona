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
         "-v", "/cgroup/:/host/sys/fs/cgroup:ro",
         "-e", "API_KEY=#{api_key}",
         tags,
         "datadog/docker-dd-agent:latest"
        ].flatten.compact.join(" ")
      end

      def tags
        "-e TAGS=\"barcelona,barcelona-dd-agent,district:#{district.name}\""
      end

      def api_key
        attributes[:api_key]
      end
    end
  end
end
