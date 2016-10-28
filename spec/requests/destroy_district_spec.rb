require 'rails_helper'

describe "DELETE /districts/:district", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district, admin_team: 'admins', developer_team: 'devs' }

  before do
    stub_github_auth(user_name: user.name, teams: github_teams)
  end

  context "when a user is a developer" do
    let(:user) { create :user }
    let(:github_teams) { ['devs'] }
    it "returns 403" do
      delete "/v1/districts/#{district.name}", nil, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user }
    let(:github_teams) { ['admins'] }
    it "destroys a district" do
      delete "/v1/districts/#{district.name}", nil, auth
      expect(response.status).to eq 204
    end
  end
end
