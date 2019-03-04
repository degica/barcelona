require "rails_helper"

describe Environment do
  describe "#ssm_path" do
    let(:heritage) { create :heritage }

    it "generates value_from" do
      env = Environment.create!(heritage: heritage, name: "ENV", ssm_path: "/path/to/secret")
      expect(env.value_from).to eq "/barcelona/#{heritage.district.name}/path/to/secret"
    end

    it "generates value_from" do
      env = Environment.create!(heritage: heritage, name: "ENV", ssm_path: "path/to/secret")
      expect(env.value_from).to eq "/barcelona/#{heritage.district.name}/path/to/secret"
    end
  end
end
