module Barcelona
  module Plugins
    class NewrelicPlugin < Base
      def on_container_instance_user_data(_instance, user_data)
        user_data.add_file("/etc/newrelic-infra.yml", "root:root", "644", <<~EOS)
          license_key: #{attributes[:license_key]}
          custom_attributes:
            role: barcelona-ci
            district: #{district.name}
        EOS

        user_data.run_commands += [
          "curl -s https://75aae388e7629eec895d26b0943bbfd06288356953c5777d:@packagecloud.io/install/repositories/newrelic/infra-beta/script.rpm.sh | bash",
          "yum install newrelic-infra -y"
        ]

        user_data
      end
    end
  end
end
