require 'rails_helper'

describe "PUT /districts/:district/plugins/:id", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:name) { "logentries" }

  it "puts a plugin" do
    # create
    params = {attributes: {token: "abcde"}}
    api_request :put, "/v1/districts/#{district.name}/plugins/#{name}", params
    expect(response.status).to eq 200

    plugin = JSON.load(response.body)["plugin"]
    expect(plugin["name"]).to eq "logentries"
    expect(plugin["attributes"]).to eq({"token" => "abcde"})

    # update
    params = {attributes: {token: "fghijk"}}
    api_request :put, "/v1/districts/#{district.name}/plugins/#{name}", params
    expect(response.status).to eq 200

    plugin = JSON.load(response.body)["plugin"]
    expect(plugin["name"]).to eq "logentries"
    expect(plugin["attributes"]).to eq({"token" => "fghijk"})

    expect(district.plugins.pluck(:name)).to eq ["logentries"]

    # delete
    api_request :delete, "/v1/districts/#{district.name}/plugins/#{name}", params
    expect(response.status).to eq 204
  end
end
