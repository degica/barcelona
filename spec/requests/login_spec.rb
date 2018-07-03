require 'rails_helper'

describe "POST /login", type: :request do
  let(:user) { create :user }
  let(:gh_auth) { {"X-GitHub-Token" => "abcdef", "Accept" => "application/json"} }
  let(:district) { create :district }
  let(:gh_stub) {
    dbl = double Octokit::Client
    allow(dbl).to receive(:user_teams) { user_teams }
    allow(dbl).to receive_message_chain(:user, :login) { user.name }
    dbl
  }

  before do
    stub_env('GITHUB_ORGANIZATION', 'degica')
    stub_env('GITHUB_DEVELOPER_TEAM', 'developers')
    stub_env('GITHUB_ADMIN_TEAM', 'Admin developers')
    allow(Octokit::Client).to receive(:new).and_return(gh_stub)
  end

  context "when user team is allowed to login" do
    let(:user_teams) { [OpenStruct.new(organization: OpenStruct.new(login: "degica"), name: "developers")] }
    it "returns login info" do
      api_request :post, "/v1/login", {}, gh_auth
      expect(response).to be_successful
      body = JSON.load(response.body)
      expect(body["user"]["name"]).to eq user.name
      expect(body["user"]["token"]).to be_present
    end
  end

  context "when user team is not allowed to login" do
    let(:user_teams) { [OpenStruct.new(organization: OpenStruct.new(login: "degica"), name: "notdevelopers")] }
    it "returns 401" do
      api_request :post, "/v1/login", {}, gh_auth
      expect(response.status).to eq 401
    end
  end
end
