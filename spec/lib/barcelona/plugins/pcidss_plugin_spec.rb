require "rails_helper"

module Barcelona
  module Plugins
    describe Barcelona::Plugins::PcidssPlugin do
      let!(:district) do
        create :district, bastion_key_pair: "bastion", plugins_attributes: [
                 {
                   name: 'pcidss',
                   plugin_attributes: {}
                 }
               ]
      end
      it "gets hooked with container_instance_user_data trigger" do
        ci = ContainerInstance.new(district)
        user_data = YAML.load(Base64.decode64(ci.user_data.build))
        expect(user_data["packages"]).to include(*described_class::SYSTEM_PACKAGES)
        expect(user_data["runcmd"]).to include(*described_class::RUN_COMMANDS)
      end

      it "gets hooked with network_stack_template trigger" do
        template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
        user_data = InstanceUserData.load(template["Resources"]["BastionServer"]["Properties"]["UserData"])
        expect(user_data.packages).to include(*described_class::SYSTEM_PACKAGES)
        expect(user_data.run_commands).to include(*described_class::RUN_COMMANDS)
      end
    end
  end
end
