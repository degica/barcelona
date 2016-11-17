require 'rails_helper'

module Barcelona
  module Plugins
    describe NewrelicPlugin do
      let(:license_key) { SecureRandom.hex }
      let!(:district) do
        create :district, plugins_attributes: [
                 {
                   name: 'newrelic',
                   plugin_attributes: {
                     "license_key" => license_key
                   }
                 }
               ]
      end

      it "gets hooked with container_instance_user_data trigger" do
        ci = ContainerInstance.new(district)
        user_data = YAML.load(Base64.decode64(ci.user_data.build))
        expect(user_data["runcmd"]).to include "yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'"
        expect(user_data["runcmd"]).to include "yum install newrelic-infra -y"
      end
    end
  end
end
