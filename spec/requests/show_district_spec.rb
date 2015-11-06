require 'rails_helper'

describe "GET /districts/:district", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let!(:plugin) { create :plugin, district: district }

  it "shows a district" do
    get "/districts/#{district.name}", nil, auth
    expect(response.status).to eq 200
    district = JSON.load(response.body)["district"]
    expect(district["plugins"]).to eq([{"name" => plugin.name, "plugin_attributes" => {}}])
  end
end
