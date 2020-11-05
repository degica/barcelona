require "rails_helper"

describe ApplicationController do
  describe "#auth_backend" do
    it "returns error when nothing is enabled" do
      stub_env("GITHUB_ORGANIZATION", nil)
      stub_env("VAULT_URL", nil)

      expect{ controller.auth_backend }.to raise_error ExceptionHandler::InternalServerError
    end

    it "returns github when github auth is enabled" do
      stub_env("VAULT_URL", nil)
      stub_env("GITHUB_ORGANIZATION", "degica")

      expect(controller.auth_backend).to be_a GithubAuth
    end

    it "returns github when github and vault auth are enabled but no vault header is provided" do
      stub_env("VAULT_URL", "https://vault.degica.com")
      stub_env("GITHUB_ORGANIZATION", "degica")

      expect(controller.auth_backend).to be_a GithubAuth
    end

    it "returns error when vault auth is enabled but no vault header is provided" do
      stub_env("GITHUB_ORGANIZATION", nil)
      stub_env("VAULT_URL", "https://vault.degica.com")

      expect{ controller.auth_backend }.to raise_error ExceptionHandler::InternalServerError
    end

    it "returns vault when vault auth is enabled but vault header is provided" do
      stub_env("GITHUB_ORGANIZATION", nil)
      stub_env("VAULT_URL", "https://vault.degica.com")

      request_double = instance_double('request')
      allow(controller).to receive(:request) { request_double }
      allow(request_double).to receive(:headers) { { 'HTTP_X_VAULT_TOKEN' => 'abcde' } }

      expect(controller.auth_backend).to be_a VaultAuth
    end
  end
end
