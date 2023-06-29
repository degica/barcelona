require 'rails_helper'

describe "PUT /districts/:district/plugins/:id", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:name) { "datadog" }

  given_auth(GithubAuth) do
    it "puts a plugin" do
      # create
      params = {attributes: {api_key: "abcde"}}
      api_request :put, "/v1/districts/#{district.name}/plugins/#{name}", params
      expect(response.status).to eq 200

      plugin = JSON.load(response.body)["plugin"]
      expect(plugin["name"]).to eq "datadog"
      expect(plugin["attributes"]).to eq({"api_key" => "abcde"})

      # update
      params = {attributes: {api_key: "fghijk"}}
      api_request :put, "/v1/districts/#{district.name}/plugins/#{name}", params
      expect(response.status).to eq 200

      plugin = JSON.load(response.body)["plugin"]
      expect(plugin["name"]).to eq "datadog"
      expect(plugin["attributes"]).to eq({"api_key" => "fghijk"})

      expect(district.plugins.pluck(:name)).to eq ["datadog"]

      # delete
      api_request :delete, "/v1/districts/#{district.name}/plugins/#{name}", params
      expect(response.status).to eq 204
    end
  end
end
