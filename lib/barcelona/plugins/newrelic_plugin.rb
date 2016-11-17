module Barcelona
  module Plugins
    class NewrelicPlugin < Base
      def on_container_instance_user_data(_instance, user_data)
        user_data.add_file("/etc/newrelic-infra.yml", "root:root", "644", <<~EOS)
          license_key: #{attributes["license_key"]}
          custom_attributes:
            role: barcelona-ci
            district: #{district.name}
        EOS

        user_data.add_file("/etc/yum.repos.d/newrelic-infra.repo", "root:root", "644", <<~EOS)
          [newrelic-infra]
          name=New Relic Infrastructure
          baseurl=http://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64
          enable=1
          gpgcheck=0
        EOS

        user_data.run_commands += [
          "yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'",
          "yum install newrelic-infra -y"
        ]

        user_data
      end
    end
  end
end
