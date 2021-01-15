require "rails_helper"

describe Environment do
  let(:heritage) { create :heritage }

  describe "validations" do
    it "value wins if both value and value_from are set" do
      env = Environment.create!(heritage: heritage, name: "ENV", value: "raw value", ssm_path: "/path/to/secret")
      expect(env.value).to eq "raw value"
      expect(env.value_from).to eq nil
    end

    it "nullify value_from when value is set while value_from exists" do
      env = Environment.create!(heritage: heritage, name: "ENV", ssm_path: "/path/to/secret")
      env.update!(value: "raw value")

      expect(env.value).to eq "raw value"
      expect(env.value_from).to eq nil
    end

    it "nullify value_from when value is set while value_from exists" do
      env = Environment.create!(heritage: heritage, name: "ENV", value: "raw value")
      env.update!(ssm_path: "path/to/secret")

      expect(env.value).to eq nil
      expect(env.value_from).to eq "/barcelona/#{heritage.district.name}/path/to/secret"
    end
  end

  describe "#ssm_path" do
    it "generates value_from" do
      env = Environment.create!(heritage: heritage, name: "ENV", ssm_path: "/path/to/secret")
      expect(env.value).to eq nil
      expect(env.value_from).to eq "/barcelona/#{heritage.district.name}/path/to/secret"
    end

    it "updates value_from" do
      env = Environment.create!(heritage: heritage, name: "ENV", ssm_path: "/path/to/secret")
      env.update!(ssm_path: "new/path")
      expect(env.value).to eq nil
      expect(env.value_from).to eq "/barcelona/#{heritage.district.name}/new/path"
    end
  end
end
