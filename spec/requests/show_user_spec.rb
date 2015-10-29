require 'rails_helper'

describe "GET /user", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"], districts: [district] }

  before do
    allow_any_instance_of(District).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
  end

  it "shows user information" do
    get "/user", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user.name
    expect(body["districts"]).to eq [district.name]
    expect(body["roles"]).to eq ["developer"]
  end
end
