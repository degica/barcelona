require 'rails_helper'

describe "POST /v1/review_groups", type: :request do
  let(:user) { create :user, roles: roles }
  let(:endpoint) { create :endpoint }
  let(:params) do
    {
      name: "example",
      base_domain: "reviewapps.degica.com",
      endpoint: endpoint.name
    }
  end

  context "when developer user" do
    let(:roles) { ["developer"] }

    it "creates a review group" do
      api_request(:post, "/v1/review_groups", params)
      expect(response.status).to eq 403
    end
  end

  context "when admin user" do
    let(:roles) { ["admin"] }

    it "creates a review group" do
      api_request(:post, "/v1/review_groups", params)
      expect(response.status).to eq 200
      group = JSON.load(response.body)["review_group"]
      expect(group["name"]).to eq "example"
      expect(group["base_domain"]).to eq "reviewapps.degica.com"
      expect(group["endpoint"]["name"]).to eq endpoint.name
    end
  end
end
