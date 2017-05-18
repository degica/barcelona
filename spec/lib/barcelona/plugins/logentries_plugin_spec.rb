require 'rails_helper'

module Barcelona
  module Plugins
    describe LogentriesPlugin do
      let!(:district) do
        create :district, bastion_key_pair: "bastion", plugins_attributes: [
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

        conf_file = user_data["write_files"].find{ |f| f["path"] ==  "/etc/rsyslog.d/barcelona-logger.conf" }
        expect(conf_file["path"]).to eq "/etc/rsyslog.d/barcelona-logger.conf"
        expect(conf_file["owner"]).to eq "root:root"
        expect(conf_file["permissions"]).to eq "644"
        expect(conf_file["content"]).to be_a String
        expect(user_data["runcmd"]).to include(*described_class::RUN_COMMANDS)
      end

      it "gets hooked with network_stack_template trigger" do
        template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
        user_data = InstanceUserData.load(template["Resources"]["BastionLaunchConfiguration"]["Properties"]["UserData"])
        expect(user_data.packages).to include(*described_class::SYSTEM_PACKAGES)
        expect(user_data.run_commands).to include(*described_class::RUN_COMMANDS)
      end
    end
  end
end
