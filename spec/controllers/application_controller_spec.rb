require "rails_helper"

describe ApplicationController do
  describe "#auth_backend" do
    context "when github auth is enabled" do
      before do
        stub_env("GITHUB_ORGANIZATION", "degica")
      end

      it "returns github" do
        expect(controller.auth_backend).to be_a GithubAuth
      end
    end

    context "when vault auth is enabled" do
      before do
        stub_env("VAULT_URL", "https://vault.degica.com")
      end

      it "returns vault" do
        expect(controller.auth_backend).to be_a VaultAuth
      end
    end
  end
end
