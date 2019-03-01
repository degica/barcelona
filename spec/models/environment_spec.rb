require "rails_helper"

describe Environment do
  describe "#namespaced_value_from" do
    it "returns full arn" do
      value_from = "arn:aws:region:account-id:secret:barcelona/district/secrets"
      env = Environment.new(name: "ENV", value_from: value_from)
      expect(env.namespaced_value_from).to eq value_from
    end

    it "returns namespaced relative path" do
      value_from = "production/database_url"
      env = build :secret_environment, name: "ENV", value_from: value_from
      expect(env.namespaced_value_from).to eq "/barcelona/#{env.district.name}/production/database_url"
    end
  end
end
