require 'rails_helper'

describe "PATCH /districts/:district", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:user) { create :user }
  let(:district) { create :district, admin_team: 'admins', developer_team: 'devs' }

  before do
    stub_github_auth(user_name: user.name, teams: github_teams)
  end

  context "when a user is a developer" do
    let(:github_teams) { ['devs'] }
    it "returns 403" do
      patch "/v1/districts/#{district.name}", {}, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:github_teams) { ['admins'] }
    it "udpates a district" do
      patch "/v1/districts/#{district.name}", {}, auth
      expect(response.status).to eq 200
    end
  end
end
