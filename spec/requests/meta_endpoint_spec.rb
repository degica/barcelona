require 'rails_helper'

describe "GET /v1/meta", type: :request do
  context "when vault auth is on" do
    before do
      stub_env("VAULT_URL" => "https://vault.degica.com")
      stub_env("GITHUB_ORGANIZATION" => nil)
    end

    it "returns vault info" do
      get "/v1/meta"
      body = JSON.load(response.body)
      expect(body["auth"]["backend"]).to eq "vault"
      expect(body["auth"]["vault"]["url"]).to eq "https://vault.degica.com"
    end
  end

  context "github vault is on" do
    before do
      stub_env("GITHUB_ORGANIZATION" => "degica")
      stub_env("GITHUB_DEVELOPER_TEAM" => "developer")
      stub_env("GITHUB_ADMIN_TEAM" => "admin")
      stub_env("VAULT_URL" => nil)
    end

    it "returns vault info" do
      get "/v1/meta"
      body = JSON.load(response.body)
      expect(body["auth"]["backend"]).to eq "github"
      expect(body["auth"]["github"]["organization"]).to eq "degica"
      expect(body["auth"]["github"]["developer_team"]).to eq "developer"
      expect(body["auth"]["github"]["admin_team"]).to eq "admin"
    end
  end
end
