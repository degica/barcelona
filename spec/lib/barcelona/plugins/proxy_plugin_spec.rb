require 'rails_helper'

module Barcelona
  module Plugins
    describe ProxyPlugin do
      let!(:district) do
        create :district, plugins_attributes: [
          {
            name: 'proxy',
            plugin_attributes: {no_proxy: ["10.0.0.1"]}
          }
        ]
      end

      it "gets hooked with created trigger" do
        heritage = Heritage.last
        expect(heritage).to be_present
        expect(heritage.name).to eq "#{district.name}-proxy"
        expect(heritage.image_name).to eq "k2nr/squid"

        service = heritage.services.first
        expect(service.name).to eq "main"
        port_mapping = service.port_mappings.first
        expect(port_mapping.lb_port).to eq 3128
        expect(port_mapping.container_port).to eq 3128
      end

      it "gets hooked with destroyed trigger" do
        district.plugins.first.destroy!
        expect(Heritage.count).to be_zero
      end

      it "gets hooked with heritage_task_definition trigger" do
        heritage = district.heritages.create(name: 'heritage',
                                             image_name: "docker_image",
                                             env_vars_attributes: [
                                               {key: "ENVIRONMENT", value: "VALUE"}
                                             ])
        definition = heritage.base_task_definition("heritage")
        expect(definition[:name]).to eq "heritage"
        expect(definition[:environment]).to eq [
          {name: "http_proxy", value: "http://main.#{district.name}-proxy.bcn:3128"},
          {name: "https_proxy", value: "http://main.#{district.name}-proxy.bcn:3128"},
          {name: "no_proxy", value: "10.0.0.1,localhost,127.0.0.1,169.254.169.254,.bcn"},
          {name: "HTTP_PROXY", value: "http://main.#{district.name}-proxy.bcn:3128"},
          {name: "HTTPS_PROXY", value: "http://main.#{district.name}-proxy.bcn:3128"},
          {name: "NO_PROXY", value: "10.0.0.1,localhost,127.0.0.1,169.254.169.254,.bcn"},
          {name: "ENVIRONMENT", value: "VALUE"}
        ]
      end

      it "gets hooked with container_instance_user_data trigger" do
        section = district.sections[:private]
        ci = ContainerInstance.new(section, instance_type: 't2.micro')
        user_data = YAML.load(Base64.decode64(ci.instance_user_data))
        expect(user_data["write_files"][0]["path"]).to eq "/etc/profile.d/http_proxy.sh"
        expect(user_data["write_files"][0]["owner"]).to eq "root:root"
        expect(user_data["write_files"][0]["permissions"]).to eq "755"
        expect(user_data["write_files"][0]["content"]).to be_a String
      end

      it "gets hooked with ecs_config trigger" do
        section = district.sections[:private]
        config = section.send(:ecs_config)
        expect(config).to include "HTTP_PROXY"
        expect(config).to include "HTTPS_PROXY"
        expect(config).to include "NO_PROXY"
      end
    end
  end
end
