# SecureInstance plugin
# This plugin configure container instance and bastion instance more secure
# Usage: bcn district put-plugin discrict1 secure_instance

module Barcelona
  module Plugins
   
    class SecureInstancePlugin < Base

      def on_container_instance_user_data(_instance, user_data)
        user_data.extend SecureUserData
        user_data.install_tools_for_pcidss
        user_data.install_tcp_wrappers
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        user_data.extend SecureUserData
        user_data.apply_security_update_on_the_first_boot
        user_data.install_tools_for_pcidss
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      module SecureUserData
        def apply_security_update_on_the_first_boot
          self.boot_commands += <<~EOS.split("\n")

            if [ -f /root/.security_update_applied ]
            then
              echo 'security update was already applied, continue initializing...'
            else
              echo 'first boot, applying security update'
              yum update -y --security
              touch /root/.security_update_applied
              echo 'security update was applied, cotinue initialize after reboot...'
              reboot
            fi

          EOS
        end

        def install_tools_for_pcidss
          # Exclude different file systems such as /proc and /dev (-xdev)
          # Files that have changed within a day (-mtime -1)
          scan_command = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

          self.run_commands += [
            "amazon-linux-extras install -y epel",
            "yum install -y clamav clamav-update tmpwatch fail2ban",

            # Enable freshclam configuration
            "sed -i 's/^Example$//g' /etc/freshclam.conf",
            "sed -i 's/^FRESHCLAM_DELAY=disabled-warn.*$//g' /etc/sysconfig/freshclam",

            # Daily full file system scan
            "echo '0 0 * * * root #{scan_command}' > /etc/cron.d/clamscan",
            "service crond restart",

            # fail2ban configurations
            "echo '[DEFAULT]' > /etc/fail2ban/jail.local",
            "echo 'bantime = 1800' >> /etc/fail2ban/jail.local",
            "service fail2ban restart",

            # SSH session timeout
            "echo 'TMOUT=900 && readonly TMOUT && export TMOUT' > /etc/profile.d/tmout.sh",
          ]
        end

        def install_tcp_wrappers
          self.packages += ['tcp_wrappers']
        end
      end
    end
  end
end
