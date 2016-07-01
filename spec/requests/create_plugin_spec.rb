require 'rails_helper'

describe "POST /districts/:district/plugins", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  it "creates a plugin" do
    params = {
      name: "logentries",
      attributes: {token: "abcde"}
    }
    api_request :post, "/v1/districts/#{district.name}/plugins", params
    expect(response.status).to eq 200
    plugin = JSON.load(response.body)["plugin"]
    expect(plugin["name"]).to eq "logentries"
    expect(plugin["plugin_attributes"]).to eq({"token" => "abcde"})
  end
end
