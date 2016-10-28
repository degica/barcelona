require 'rails_helper'

describe "GET /users", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user }

  before do
    stub_github_auth(user_name: user.name)
  end

  it "shows user information" do
    get "/v1/users", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["users"]
    expect(body.count).to eq 1
  end
end
