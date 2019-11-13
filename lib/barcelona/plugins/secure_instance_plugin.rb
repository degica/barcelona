# SecureInstance plugin
# This plugin configure container instance and bastion instance more secure
# Usage: bcn district put-plugin discrict1 secure_instance

module Barcelona
  module Plugins
   
    class SecureInstancePlugin < Base

      def on_container_instance_user_data(_instance, user_data)
        user_data.extend SecureUserData
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        user_data.extend SecureUserData
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      module SecureUserData
        Packages = %w(clamav clamav-update tmpwatch fail2ban)
        def self.extended(obj)
          obj.configure_security
        end

        def configure_security
          self.boot_commands += boot_commands
          self.run_commands += run_commands
          self.packages += Packages
        end

        def boot_commands
          [
            "if [ -f /root/.security_update_applied ]",
            "then",
            "echo 'security update was already applied, continue initializing...'",
            "else",
            "echo 'first boot, applying security update'",
            "yum update -y --security",
            "touch /root/.security_update_applied",
            "echo 'security update was applied, cotinue initialize after reboot...'",
            "reboot",
            "fi"
          ]
        end

        def run_commands
          [
          ]
        end
      end
    end
  end
end
