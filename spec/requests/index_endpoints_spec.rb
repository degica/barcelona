require 'rails_helper'

describe "GET /districts/:district/endpoints", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  given_auth(GithubAuth) do
    it "returns a list of endpoint" do
      district.endpoints.create(name: "ep1")
      district.endpoints.create(name: "ep2")

      api_request(:get, "/v1/districts/#{district.name}/endpoints")
      expect(response.status).to eq 200
      endpoints = JSON.load(response.body)["endpoints"]
      expect(endpoints.count).to eq 2
      expect(endpoints[0]["name"]).to eq "ep1"
      expect(endpoints[0]["dns_name"]).to be_blank
      expect(endpoints[0]["ssl_policy"]).to eq "intermediate"
      expect(endpoints[1]["name"]).to eq "ep2"
      expect(endpoints[1]["dns_name"]).to be_blank
      expect(endpoints[1]["ssl_policy"]).to eq "intermediate"
    end
  end
end
