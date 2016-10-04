require 'rails_helper'

describe "GET /user", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user }

  before do
    stub_github_auth(user_name: user.name)
  end

  it "shows user information" do
    get "/v1/user", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user.name
  end
end

describe "GET /users/:id", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user }
  let(:user2) { create :user }

  before do
    stub_github_auth(user_name: user.name)
  end

  it "shows user information" do
    get "/v1/users/#{user2.name}", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user2.name
  end
end
