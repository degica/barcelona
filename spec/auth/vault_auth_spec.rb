require "rails_helper"

describe VaultAuth do
  let(:auth) { VaultAuth.new(request) }
  let(:cap_probe) { instance_double(Vault::CapProbe) }

  before do
    allow(VaultAuth).to receive(:vault_url) { 'https://vault-url' }
    allow(VaultAuth).to receive(:enabled?) { true }
    allow(auth).to receive(:vault_path_prefix) { 'dejiko' }
    allow(auth).to receive(:cap_probe) { cap_probe }
  end

  describe "#authenticate" do
    let(:request) do
      double(
        headers: {"HTTP_X_VAULT_TOKEN" => "abcd"},
        method: "PATCH",
        path: '/v1/something'
      )
    end

    it 'returns a user with the hash saved' do
      expect(auth.authenticate).to be_persisted
    end

    it 'returns the existing user' do
      u = User.create!(
        name: 'someuniquename',
        auth: 'vault',
        token: 'abcd',
        roles: []
      )

      expect(auth.authenticate.name).to eq 'someuniquename'
    end

    it 'returns the user with token filled in' do
      # This is needed to make vault calls.
      User.create!(
        name: 'asdasd',
        auth: 'vault',
        token: 'abcd',
        roles: []
      )

      expect(auth.authenticate.token).to eq 'abcd'
    end
  end

  describe "#login" do
    let(:request) { double({}) }
    it 'calls authenticate' do
      expect(auth).to receive(:authenticate)
      auth.login
    end
  end

  describe '#authorize_action' do
    let(:request) { double(path: '/v1/something', method: "TEST") }

    it "does not raise error when the given vault token has access to the Barcelona API" do
      expect(cap_probe).to receive(:authorized?) { true }
      expect{ auth.authorize_action }.to_not raise_error
    end

    it "raises an error when the given vault token does not have access to the Barcelona API" do
      expect(cap_probe).to receive(:authorized?) { false }
      expect{ auth.authorize_action }.to raise_error ExceptionHandler::Forbidden
    end
  end
end
