# SecureInstance plugin
# This plugin configure container instance and bastion instance more secure
# Usage: bcn district put-plugin discrict1 secure_instance

module Barcelona
  module Plugins
   
    class SecureInstancePlugin < Base
      Packages = %w(clamav clamav-update tmpwatch fail2ban)
      def on_container_instance_user_data(_instance, user_data)
        configure_security(user_data)
        user_data
      end

      def configure_security(user_data)
        user_data.boot_commands += boot_commands
        user_data.run_commands += run_commands
        user_data.packages += Packages
      end

      def boot_commands
        @boot_commands ||= [
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
        ].flatten
      end

      def run_commands
        @run_commands ||= [
        ].flatten
      end

    end
  end
end
