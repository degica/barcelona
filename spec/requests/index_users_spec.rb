require 'rails_helper'

describe "GET /users", type: :request do
  let(:district) { create :district }
  let(:user) { create :user, roles: ["developer"] }

  it "shows user information" do
    api_request :get, "/v1/users"
    expect(response.status).to eq 200
    body = JSON.load(response.body)["users"]
    expect(body.count).to eq 1
  end
end
