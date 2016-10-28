require 'rails_helper'

describe "POST /districts/:district/sign_public_key", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district, admin_team: 'admins', developer_team: 'devs' }
  let(:ca_key_pair) { OpenSSL::PKey::RSA.new(1024) }
  let(:user) { create :user, public_key: public_key }
  let(:public_key) do
    key = OpenSSL::PKey::RSA.new(1024).public_key
    "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
  end

  before do
    allow_any_instance_of(District).to receive(:get_ca_key) { ca_key_pair.to_pem }
    stub_github_auth(user_name: user.name, teams: github_teams)
  end

  context "when a user is a developer" do
    let(:github_teams) { ['devs'] }
    it "returns 403" do
      post "/v1/districts/#{district.name}/sign_public_key", {}, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:github_teams) { ['admins'] }
    it "udpates a district" do
      post "/v1/districts/#{district.name}/sign_public_key", {}, auth
      expect(response.status).to eq 200
      resp = JSON.parse(response.body)
      expect(resp["district"]).to be_present
      expect(resp["certificate"]).to be_a String
    end
  end
end
