module Barcelona
  module Plugins
    class NtpPlugin < Base
      def on_container_instance_user_data(instance, user_data)
        user_data.boot_commands += [
          "sed -i '/^server /s/^/#/' /etc/ntp.conf",
          hosts.map { |h| "echo server #{h} iburst >> /etc/ntp.conf" },
          "service ntpd restart"
        ].flatten
        user_data
      end

      private

      def hosts
        attributes["ntp_hosts"] || []
      end
    end
  end
end
