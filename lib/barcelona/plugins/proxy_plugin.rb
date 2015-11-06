module Barcelona
  module Plugins
    class ProxyPlugin < Base
      PROXY_URL = "http://main.proxy.bcn:3128"

      def on_container_instance_user_data(_, user_data)
        user_data.add_file("/etc/profile.d/http_proxy.sh", "root:root", "755", <<EOS)
#!/bin/bash
export http_proxy=#{PROXY_URL}
export https_proxy=#{PROXY_URL}
EOS
        user_data
      end

      def on_heritage_task_definition(heritage, task_definition)
        return task_definition if heritage.name == proxy_heritage_name
        task_definition[:environment] += [
          {name: "http_proxy", value: PROXY_URL},
          {name: "https_proxy", value: PROXY_URL}
        ]
        task_definition
      end

      def on_created(_, _)
        district.heritages.create(
          name: proxy_heritage_name,
          image_name: "degica/squid",
          section_name: "public",
          services_attributes: [
            {
              name: "main",
              cpu: 256,
              memory: 256,
              port_mappings_attributes: [
                {lb_port: 3128, container_port: 3128}
              ]
            }
          ]
        )
      end

      def on_destroyed(_, _)
        heritage = district.heritages.find_by(name: proxy_heritage_name)
        heritage.destroy!
      end

      private

      def district
        model.district
      end

      def proxy_heritage_name
        "#{district.name}-proxy"
      end
    end
  end
end
