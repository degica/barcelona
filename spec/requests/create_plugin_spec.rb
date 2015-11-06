require 'rails_helper'

describe "POST /districts/:district/plugins", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "creates a plugin" do
    params = {
      name: "proxy"
    }
    post "/districts/#{district.name}/plugins", params, auth
    expect(response.status).to eq 200
    plugin = JSON.load(response.body)["plugin"]
    expect(plugin["name"]).to eq "proxy"
    expect(plugin["plugin_attributes"]).to eq({})
  end
end
