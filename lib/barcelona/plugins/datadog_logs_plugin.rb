module Barcelona
  module Plugins
    class DatadogLogsPlugin < Base
      LOCAL_LOGGER_PORT = 514
      SYSTEM_PACKAGES = %w[rsyslog-gnutls ca-certificates]
      RUN_COMMANDS = [
        "service rsyslog restart"
      ]

      def on_container_instance_user_data(_instance, user_data)
        update_user_data(user_data, "ci") # ci stands for Container Instance
        user_data
      end

      def on_heritage_task_definition(_heritage, task_definition)
        task_definition.merge(
          log_configuration: {
            log_driver: "syslog",
            options: {
              "syslog-address" => "tcp://127.0.0.1:#{LOCAL_LOGGER_PORT}",
              "tag" => task_definition[:name]
            }
          }
        )
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        update_user_data(user_data, "bastion")
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      private

      def rsyslog_conf(role)
        <<~CONF
          $ModLoad imtcp
          $InputTCPServerRun #{LOCAL_LOGGER_PORT}

          ## Set the Datadog Format to send the logs
          $template DatadogFormat,"#{api_key} <%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% - - [metas ddsource=\\"host\\" ddtags=\\"barcelona,barcelona-dd-agent,district:#{district.name},barcelona:#{district.name}\\"] %msg%\\n"

          ## Define the destination for the logs

          $DefaultNetstreamDriverCAFile /etc/ssl/certs/ca-bundle.crt
          $ActionSendStreamDriver gtls
          $ActionSendStreamDriverMode 1
          $ActionSendStreamDriverAuthMode x509/name
          $ActionSendStreamDriverPermittedPeer *.logs.datadoghq.com
          *.* @@intake.logs.datadoghq.com:10516;DatadogFormat

          ## Keep connections alive
          $ModLoad immark
          $MarkMessagePeriod 20
        CONF
      end

      def update_user_data(user_data, role)
        user_data.packages += SYSTEM_PACKAGES
        user_data.add_file("/etc/rsyslog.d/datadog.conf", "root:root", "644", rsyslog_conf(role))
        user_data.run_commands += RUN_COMMANDS
      end

      def token
        model.plugin_attributes["token"]
      end

      def api_key
        attributes["api_key"]
      end
    end
  end
end
