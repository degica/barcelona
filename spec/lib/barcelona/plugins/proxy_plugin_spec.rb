require 'rails_helper'

module Barcelona
  module Plugins
    describe ProxyPlugin do
      let!(:district) { create :district, plugins_attributes: [{name: 'proxy'}] }

      it "gets hooked with created trigger" do
        heritage = Heritage.last
        expect(heritage).to be_present
        expect(heritage.name).to eq "#{district.name}-proxy"
        expect(heritage.image_name).to eq "degica/squid"

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
                                              {name: "ENVIRONMENT", value: "VALUE"},
                                              {name: "http_proxy", value: "http://main.proxy.bcn:3128"},
                                              {name: "https_proxy", value: "http://main.proxy.bcn:3128"},
                                            ]
      end

      it "gets hooked with container_instance_user_data trigger" do
        section = district.sections[:public]
        ci = ContainerInstance.new(section, instance_type: 't2.micro')
        user_data = YAML.load(Base64.decode64(ci.instance_user_data))
        expect(user_data["write_files"][0]["path"]).to eq "/etc/profile.d/http_proxy.sh"
        expect(user_data["write_files"][0]["owner"]).to eq "root:root"
        expect(user_data["write_files"][0]["permissions"]).to eq "755"
        expect(user_data["write_files"][0]["content"]).to be_a String
      end
    end
  end
end
