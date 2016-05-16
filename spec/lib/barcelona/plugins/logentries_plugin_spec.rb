require 'rails_helper'

module Barcelona
  module Plugins
    describe LogentriesPlugin do
      let!(:district) do
        create :district, plugins_attributes: [
          {
            name: 'logentries',
            plugin_attributes: {
              token: "logentries_token"
            }
          }
        ]
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
                                                       "tag" => "heritage"
                                                     })
      end

      it "gets hooked with container_instance_user_data trigger" do
        ci = ContainerInstance.new(district)
        user_data = YAML.load(Base64.decode64(ci.user_data.build))

        cert_file = user_data["write_files"].find{ |f| f["path"] == "/etc/ssl/certs/logentries.all.crt" }
        expect(cert_file["path"]).to eq "/etc/ssl/certs/logentries.all.crt"
        expect(cert_file["owner"]).to eq "root:root"
        expect(cert_file["permissions"]).to eq "644"
        expect(cert_file["content"]).to be_a String

        conf_file = user_data["write_files"].find{ |f| f["path"] ==  "/etc/rsyslog.d/barcelona-logger.conf" }
        expect(conf_file["path"]).to eq "/etc/rsyslog.d/barcelona-logger.conf"
        expect(conf_file["owner"]).to eq "root:root"
        expect(conf_file["permissions"]).to eq "644"
        expect(conf_file["content"]).to be_a String
      end
    end
  end
end
