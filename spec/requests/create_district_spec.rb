require 'rails_helper'

describe "POST /districts", :vcr, type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }

  before do
    allow_any_instance_of(District).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
  end
  let(:params) do
    {
      name: "district",
      vpc_id: "vpcid",
      private_hosted_zone_id: "hosted_zone",
      aws_access_key_id: "awsaccessskeyid",
      aws_secret_access_key: "secret key"
    }
  end

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 401" do
      post "/districts", params, auth
      expect(response.status).to eq 401
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "creates a district" do
      post "/districts", params, auth
      expect(response.status).to eq 200
    end
  end
end
