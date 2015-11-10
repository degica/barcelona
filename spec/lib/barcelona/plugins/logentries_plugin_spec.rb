require 'rails_helper'

module Barcelona
  module Plugins
    describe LogentriesPlugin do
      let!(:district) { create :district,
                               plugins_attributes: [
                                 {
                                   name: 'logentries',
                                   plugin_attributes: {
                                     token: "logentries_token"
                                   }
                                 }
                               ]
      }

      it "gets hooked with created trigger" do
        heritage = Heritage.last
        expect(heritage).to be_present
        expect(heritage.name).to eq "#{district.name}-logger"
        expect(heritage.image_name).to eq "k2nr/rsyslog-logentries"

        service = heritage.services.first
        expect(service.name).to eq "main"
        port_mapping = service.port_mappings.first
        expect(port_mapping.lb_port).to eq 514
        expect(port_mapping.container_port).to eq 514
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
        expect(definition[:log_configuration]).to eq(log_driver: "syslog",
                                                     options: {
                                                       "syslog-address" => "tcp://127.0.0.1:514",
                                                       "syslog-tag" => "heritage"
                                                     })
      end

      it "gets hooked with container_instance_user_data trigger" do
        section = district.sections[:private]
        ci = ContainerInstance.new(section, instance_type: 't2.micro')
        user_data = YAML.load(Base64.decode64(ci.instance_user_data))
        expect(user_data["write_files"][0]["path"]).to eq "/etc/rsyslog.d/barcelona-logger.conf"
        expect(user_data["write_files"][0]["owner"]).to eq "root:root"
        expect(user_data["write_files"][0]["permissions"]).to eq "644"
        expect(user_data["write_files"][0]["content"]).to be_a String
      end
    end
  end
end
