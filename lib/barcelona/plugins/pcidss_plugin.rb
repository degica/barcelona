module Barcelona
  module Plugins
    class PcidssPlugin < Base
      SYSTEM_PACKAGES = ["clamav", "clamav-update", "tmpwatch", "fail2ban"]
      # Exclude different file systems such as /proc and /dev (-xdev)
      # Files that have changed within a day (-mtime -1)
      SCAN_COMMAND = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"
      RUN_COMMANDS = [
        # Enable freshclam configuration
        "sed -i 's/^Example$//g' /etc/freshclam.conf",
        "sed -i 's/^FRESHCLAM_DELAY=disabled-warn.*$//g' /etc/sysconfig/freshclam",
        # Daily full file system scan
        "echo '0 0 * * * root #{SCAN_COMMAND}' > /etc/cron.d/clamscan",
        "service crond restart",
        # fail2ban configurations
        "echo '[DEFAULT]' > /etc/fail2ban/jail.local",
        "echo 'bantime = 1800' >> /etc/fail2ban/jail.local",
        "service fail2ban restart",
        # SSH session timeout
        "echo 'TMOUT=900 && readonly TMOUT && export TMOUT' > /etc/profile.d/tmout.sh"
      ]

      def on_container_instance_user_data(_instance, user_data)
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += RUN_COMMANDS

        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_server = template["BastionServer"]
        return template if bastion_server.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_server["Properties"]["UserData"])
        user_data.packages += SYSTEM_PACKAGES
        user_data.run_commands += RUN_COMMANDS
        bastion_server["Properties"]["UserData"] = user_data.build
        template
      end
    end
  end
end
