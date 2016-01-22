require 'rails_helper'

describe "POST /districts", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }

  let(:params) do
    {
      name: "district",
      aws_access_key_id: "awsaccessskeyid",
      aws_secret_access_key: "secret key",
      s3_bucket_name: "degica-barcelona"
    }
  end

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 403" do
      post "/v1/districts", params, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "creates a district" do
      post "/v1/districts", params, auth
      expect(response.status).to eq 201
    end
  end
end
