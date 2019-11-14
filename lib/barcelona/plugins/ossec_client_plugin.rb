# OssecClient plugin
# This plugin adds a wazuh agent which connects to existing ossec manager
# Usage: bcn district put-plugin discrict1 ossec_client -a server_hostname=ossec-manager.local 
# To connect a ossec manager in other VPC, you need to ...
# - Add VPC to Route53 Hosted Zone
# - Create a peering connection
# - Add an entry for peering to both Container VPC and ossec manager VPC
# - Allow access from Container VPC to ossec manager VPC

module Barcelona
  module Plugins
    class OssecClientPlugin < Base
      def on_container_instance_user_data(_instance, user_data)
        user_data.extend OssecClientUserData
        user_data.configure_ossec_client(attributes["server_hostname"])
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        user_data.extend OssecClientUserData
        user_data.configure_ossec_client(attributes["server_hostname"])
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      module OssecClientUserData
        def configure_ossec_client(server_hostname)
          self.packages += ['wazuh-agent']
          self.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<~EOS)
            [wazuh_repo]
            gpgcheck=1
            gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
            enabled=1
            name=Wazuh
            baseurl=https://packages.wazuh.com/yum/el/7/x86_64
            protect=1
          EOS

          sed_command1 = "s/<server-ip>.*<\\/server-ip>/<server-hostname>#{server_hostname}<\\/server-hostname>/g"
          sed_command2 = "s/<\\/rootcheck>/<ignore>\\/var\\/lib\\/docker\\/overlay2<\\/ignore><\\/rootcheck>/"
          self.run_commands += <<~EOS.split("\n")
            set +e # Ignores error on OSSEC installation process.
            sed -i -e '#{sed_command1}' -e '#{sed_command2}' /var/ossec/etc/ossec.conf
            /var/ossec/bin/agent-auth -m #{server_hostname}
            /var/ossec/bin/ossec-control restart
            set -e
          EOS
        end
      end
    end
  end
end
