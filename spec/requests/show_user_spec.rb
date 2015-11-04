require 'rails_helper'

describe "GET /user", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"], districts: [district] }

  it "shows user information" do
    get "/user", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user.name
    expect(body["districts"]).to eq [district.name]
    expect(body["roles"]).to eq ["developer"]
  end
end

describe "GET /users/:id", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"], districts: [district] }
  let(:user2) { create :user, name: 'user2', roles: ["developer"], districts: [district] }

  it "shows user information" do
    get "/users/#{user2.name}", nil, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user2.name
    expect(body["districts"]).to eq [district.name]
    expect(body["roles"]).to eq ["developer"]
  end
end
