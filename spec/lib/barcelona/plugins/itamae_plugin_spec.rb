require "rails_helper"
require 'barcelona/plugins/ossec_client_plugin'

module Barcelona
  module Plugins
    describe ItamaePlugin do
      let!(:district) do
        build :district, bastion_key_pair: "bastion", plugins_attributes: [
          {
            name: 'itamae',
            plugin_attributes: {
              "recipe_url": "s3://barcelona-district1-12345/itamae_recipes/recipe.tar.gz"
            }
          }
        ]
      end

      shared_examples_for('itamae') do
        it "installs itamae" do
          expect(user_data["runcmd"]).to include(%r[gem install itamae])
        end

        it "install itamae and apply recipe" do
          itamae_command = user_data['write_files'].find do |f|
            f['path'] == '/usr/local/bin/apply_itamae.sh'
          end
          expect(itamae_command['content']).to match %r[itamae]
          expect(user_data["runcmd"]).to include("/usr/local/bin/apply_itamae.sh")
        end
      end

      context "gets hooked with container_instance_user_data trigger" do
        before do
          district.save!
        end
        let(:ci) { ContainerInstance.new(district) }
        let(:user_data) {YAML.load(Base64.decode64(ci.user_data.build)) } 
        it_behaves_like('itamae')
      end

      context "when hooked with network_stack_template trigger" do
        before do
          district.save!
        end

        let(:user_data) do
          template = JSON.load(::Barcelona::Network::NetworkStack.new(district).target!)
          user_data_base64 = template["Resources"]["BastionLaunchConfiguration"]["Properties"]["UserData"]
          YAML.load(Base64.decode64(user_data_base64))
        end
        it_behaves_like('itamae')
      end
    end
  end
end
