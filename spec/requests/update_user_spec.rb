require 'rails_helper'

describe "PATCH /user", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:user) { create :user }

  before do
    stub_github_auth(user_name: user.name)
  end

  it "updates user information" do
    params = {
      "public_key" => "ssh-rsa aaaaaaaa"
    }
    patch "/v1/user", params, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["user"]
    expect(body["name"]).to eq user.name
    expect(body["public_key"]).to eq "ssh-rsa aaaaaaaa"
  end
end
