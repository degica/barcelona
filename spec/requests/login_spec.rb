require 'rails_helper'

describe "POST /login", type: :request do
  let(:user) { create :user }
  let(:gh_auth) { {"X-GitHub-Token" => "abcdef", "Accept" => "application/json"} }

  before do
    stub_github_auth(user_name: user.name, org: 'org')
  end

  context "When a user belongs to github organization" do
    before do
      ENV['GITHUB_ORGANIZATION'] = 'org'
    end

    it "returns login info" do
      post "/v1/login", nil, gh_auth
      expect(response).to be_success
      body = JSON.load(response.body)
      expect(body["user"]["name"]).to eq user.name
      expect(body["user"]["token"]).to be_present
    end
  end

  context "When a user doesn't belong to github organization" do
    let(:user_teams) { [OpenStruct.new(organization: OpenStruct.new(login: "degica"), name: "notdevelopers")] }

    before do
      ENV['GITHUB_ORGANIZATION'] = 'other_org'
    end

    it "returns 401" do
      post "/v1/login", nil, gh_auth
      expect(response.status).to eq 401
    end
  end
end
