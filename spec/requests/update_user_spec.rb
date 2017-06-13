require 'rails_helper'

describe "PATCH /users/:id", type: :request do
  let(:district) { create :district }
  let(:user) { create :user, roles: [role] }
  let(:user2) { create :user, roles: ["developer"] }

  context "when a user is admin" do
    let(:role) { "admin" }
    it "updates user information" do
      params = {
        "public_key" => "ssh-rsa aaaaaaaa"
      }
      api_request :patch, "/v1/users/#{user2.name}", params
      expect(response.status).to eq 200
      body = JSON.load(response.body)["user"]
      expect(body["name"]).to eq user.name
      expect(body["public_key"]).to eq "ssh-rsa aaaaaaaa"
    end
  end

  context "when a user is developer" do
    let(:role) { "developer" }

    it "is forbidden" do
      params = {
        "public_key" => "ssh-rsa aaaaaaaa"
      }
      api_request :patch, "/v1/users/#{user2.name}", params
      expect(response.status).to eq 403
    end
  end
end

describe "PATCH /user", type: :request do
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"] }

  it "updates user information" do
    params = {
      "public_key" => "ssh-rsa aaaaaaaa"
    }
    api_request :patch, "/v1/user", params
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user.name
    expect(body["public_key"]).to eq "ssh-rsa aaaaaaaa"
  end
end
