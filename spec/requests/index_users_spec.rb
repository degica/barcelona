require 'rails_helper'

describe "GET /users", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"], districts: [district] }

  before do
    allow_any_instance_of(District).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
  end

  it "shows user information" do
    get "/users", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["users"]
    expect(body.count).to eq 1
  end
end
