require "rails_helper"

describe VaultAuth do
  let(:auth) { VaultAuth.new(request) }

  describe "#authenticate" do
    let(:request) do
      double(headers: {"HTTP_X_VAULT_TOKEN" => "vault-token"})
    end
    subject { auth.authenticate }

    before do
      @stub = stub_request(:get, "#{ENV['VAULT_URL']}/v1/auth/token/lookup-self").
        with(headers: {"X-Vault-Token" => "vault-token"}).
        to_return(body: {data: {meta: {username: "k2nr"}}}.to_json)
    end

    its(:name) { is_expected.to eq "k2nr" }
  end

  describe "#authorize_action" do
    let(:path) { "/v1/districts/default" }
    let(:request) do
      double(
        headers: {"HTTP_X_VAULT_TOKEN" => "vault-token"},
        method: "PATCH",
        path: path
      )
    end
    subject { auth.authorize_action }

    context "when the given vault token has access to the Barcelona API" do
      before do
        @stub = stub_request(:post, "#{ENV['VAULT_URL']}/v1/sys/capabilities-self").
          with(headers: {"X-Vault-Token" => "vault-token"},
               body: {path: "secret/Barcelona/#{ENV['VAULT_PATH_PREFIX']}#{path}"}.to_json
              ).
          to_return(body: {capabilities: ["update"]}.to_json)
      end

      it { expect{subject}.to_not raise_error }
    end

    context "when the given vault token does not have access to the Barcelona API" do
      before do
        @stub = stub_request(:post, "#{ENV['VAULT_URL']}/v1/sys/capabilities-self").
          with(headers: {"X-Vault-Token" => "vault-token"},
               body: {path: "secret/Barcelona/#{ENV['VAULT_PATH_PREFIX']}#{path}"}.to_json
              ).
          to_return(body: {capabilities: ["read"]}.to_json)
      end

      it { expect{subject}.to raise_error ExceptionHandler::Forbidden }
    end
  end
end
