module Barcelona
  module Plugins
    class LogentriesPlugin < Base
      LOGGER_PORT = 20514 # TCP port for logger service ELB
      LOCAL_LOGGER_PORT = 514 # TCP port for local rsyslog
      CONTAINER_PORT = 514 # TCP container port for a logger container

      def on_container_instance_user_data(_instance, user_data)
        user_data.add_file("/etc/rsyslog.d/barcelona-logger.conf", "root:root", "644", <<EOS)
$ModLoad imtcp
$InputTCPServerRun #{LOCAL_LOGGER_PORT}
$template LineTemplate,"%syslogtag% hostname=%hostname% %msg:1:1024%\\n"
*.* @@#{logger_url};LineTemplate
EOS
        user_data.run_commands += [
          "service rsyslog restart"
        ]

        user_data
      end

      def on_heritage_task_definition(_heritage, task_definition)
        task_definition.merge(
          log_configuration: {
            log_driver: "syslog",
            options: {
              "syslog-address" => "tcp://127.0.0.1:#{LOCAL_LOGGER_PORT}",
              # TODO: Since docker 1.9.0 `syslog-tag` has been marked as deprecated and
              # the option name changed to `tag`
              # `syslog-tag` option will be removed at docker 1.11.0
              "syslog-tag" => task_definition[:name]
            }
          }
        )
      end

      def on_created(_, _)
        params = {
          name: logger_heritage_name,
          image_name: "k2nr/rsyslog-logentries",
          section_name: "public",
          env_vars: {
            "LE_TOKEN" => token
          },
          services: [
            {
              name: "main",
              cpu: 256,
              memory: 256,
              port_mappings: [
                {lb_port: LOGGER_PORT, container_port: CONTAINER_PORT}
              ]
            }
          ]
        }
        logger_heritage = BuildHeritage.new(params, district: district).execute
        logger_heritage.save_and_deploy!
      end

      def on_updated(_, _)
        heritage = Heritage.find_by!(name: logger_heritage_name)
        env_var = heritage.env_vars.find_by(key: "LE_TOKEN")
        env_var.update!(value: token)
        heritage.save_and_deploy!(without_before_deploy: true)
      end

      def on_destroyed(_, _)
        heritage = district.heritages.find_by(name: logger_heritage_name)
        heritage.destroy!
      end

      private

      def district
        model.district
      end

      def logger_heritage_name
        "#{district.name}-logger"
      end

      def token
        model.plugin_attributes[:token]
      end

      def logger_url
        "main.#{logger_heritage_name}.bcn:#{LOGGER_PORT}"
      end
    end
  end
end
