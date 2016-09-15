module Barcelona
  module Plugins
    class LogentriesPlugin < Base
      LOCAL_LOGGER_PORT = 514 # TCP port for local rsyslog
      SYSTEM_PACKAGES = ["rsyslog-gnutls"]
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
        bastion_server = template["BastionServer"]
        return template if bastion_server.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_server["Properties"]["UserData"])
        update_user_data(user_data, "bastion")
        bastion_server["Properties"]["UserData"] = user_data.build
        template
      end

      private

      def rsyslog_conf(role)
        <<EOS
$ModLoad imtcp
$InputTCPServerRun #{LOCAL_LOGGER_PORT}

$DefaultNetstreamDriverCAFile /etc/ssl/certs/ca-bundle.crt
$ActionSendStreamDriver gtls
$ActionSendStreamDriverMode 1
$ActionSendStreamDriverAuthMode x509/name
$ActionSendStreamDriverPermittedPeer *.logentries.com

$template LogentriesTemplate,"#{token} %syslogtag% role=#{role} hostname=%hostname% %msg:1:1024%\\n"
*.* @@data.logentries.com:443;LogentriesTemplate
EOS
      end

      def update_user_data(user_data, role)
        user_data.packages += SYSTEM_PACKAGES
        user_data.add_file("/etc/rsyslog.d/barcelona-logger.conf", "root:root", "644", rsyslog_conf(role))
        user_data.run_commands += RUN_COMMANDS
      end

      def token
        model.plugin_attributes[:token]
      end
    end
  end
end
