require 'rails_helper'

describe "POST /login", :vcr, type: :request do
  let(:user) { create :user }
  let(:gh_auth) { {"X-GitHub-Token" => "abcdef", "Accept" => "application/json"} }
  let(:district) { create :district }
  let(:gh_stub) {
    dbl = double Octokit::Client
    allow(dbl).to receive(:user_teams) { user_teams }
    allow(dbl).to receive_message_chain(:user, :login) { user.name }
    dbl
  }

  before {Aws.config[:stub_responses] = true}
  before do
    allow(Octokit::Client).to receive(:new).and_return(gh_stub)
  end

  context "when user team is allowed to login" do
    let(:user_teams) { [OpenStruct.new(organization: OpenStruct.new(login: "degica"), name: "developers")] }
    it "returns login info" do
      post "/login", nil, gh_auth
      expect(response).to be_success
      login = JSON.load(response.body)
      expect(login["login"]).to eq user.name
      expect(login["token"]).to be_a String
    end
  end

  context "when user team is not allowed to login" do
    let(:user_teams) { [OpenStruct.new(organization: OpenStruct.new(login: "degica"), name: "notdevelopers")] }
    it "returns 401" do
      post "/login", nil, gh_auth
      expect(response.status).to eq 401
    end
  end
end
