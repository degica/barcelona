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
   
    class ItamaePlugin < Base

      def on_container_instance_user_data(_instance, user_data)
        install_itamae(user_data)
        apply_itamae_recipe(user_data, attributes['recipe_url'], 'barcelona_container')
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        install_itamae(user_data)
        apply_itamae_recipe(user_data, attributes['recipe_url'], 'barcelona_bastion')
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      private
      def install_itamae(user_data)
        user_data.packages += %w(
          gcc-c++
          redhat-rpm-config
        )
        user_data.run_commands += <<~EOS.split("\n")
          amazon-linux-extras install ruby2.4
          yum install -y ruby-devel
          gem install itamae io-console -N
        EOS
      end

      def apply_itamae_recipe(user_data, recipe_url, role)
        archive = Pathname.new(URI.parse(recipe_url).path).basename
        user_data.add_file("/usr/local/bin/apply_itamae.sh", "root:root", "755", <<~EOS)
          #!/bin/bash
          set -ex
          # download the recipe
          mkdir /root/itamae && cd /root/itamae
          aws s3 cp #{recipe_url} .
          tar zxvf #{archive}
          # Make sudo usable without tty
          sed -i -e "s/^ *Defaults *requiretty/# Defaults requiretty/" /etc/sudoers
          # apply itamae recipe
          itamae local roles/#{role}.rb -y nodes/#{role}.yml -l info > /var/log/itamae.log
        EOS

        user_data.add_file("/etc/systemd/system/itamae.service", "root:root", "644", <<~EOS)
          [Unit]
          Description=Download Itamae recipe and apply it
          After=syslog.target network.target

          [Service]
          Type=oneshot

          ExecStart=/usr/local/bin/apply_itamae.sh

          [Install]
          WantedBy=multi-user.target
        EOS
        user_data.run_commands += [
          'systemctl start itamae'
        ]
      end
    end
  end
end
