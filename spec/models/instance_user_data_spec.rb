require 'rails_helper'

describe InstanceUserData do
  let(:user) { create :user, public_key: 'abc' }
  let(:run_commands) { [ "echo abc" ] }
  let(:packages) { [ "ruby" ] }
  let(:cloud_final_modules) { [] }
  describe "#build" do
    subject do
      described_class.load_or_initialize.tap do |userdata|
        userdata.run_commands += run_commands
        userdata.packages +=  packages
        userdata.cloud_final_modules = cloud_final_modules
      end.build
    end

    it "generates base64 eoncoded yaml string" do
      yml = YAML.load(Base64.decode64(subject))
      expect(yml['runcmd']).to eq(run_commands)
      expect(yml['packages']).to eq(packages)
    end

    context "with cloud_final_modules" do
      let(:cloud_final_modules) { [['scripts-user', 'always']] }

      it "generates cloud_final_modules directive" do
        yml = YAML.load(Base64.decode64(subject))
        expect(yml['cloud_final_modules']).to eq([['scripts-user', 'always']])
      end
    end
  end
end
