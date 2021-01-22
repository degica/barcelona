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

  describe "#username" do
    let(:request) do
      double(
        headers: {"HTTP_X_VAULT_TOKEN" => "abcd"},
        method: "PATCH",
        path: '/v1/something'
      )
    end

    let(:reply) { instance_double('whatever_vault_uses') }

    before do
      client = instance_double(Vault::Client)
      intermediate = instance_double('whatever_vault_uses')
      allow(Vault::Client).to receive(:new) { client }
      allow(client).to receive(:auth) { intermediate }
      allow(intermediate).to receive(:token) { reply }
    end

    it 'gives the username' do
      allow(reply).to receive(:data) { { meta: { username: 'foobar' } } }
      expect(auth.username).to eq 'foobar'
    end

    it 'gives the placeholder name if vault does not return a username' do
      allow(reply).to receive(:data) { { meta: { random: 'stuff' } } }
      expect(auth.username).to start_with 'vault-user'
    end
  end

  describe "#authenticate" do
    let(:request) do
      double(
        headers: {"HTTP_X_VAULT_TOKEN" => "abcd"},
        method: "PATCH",
        path: '/v1/something'
      )
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

    it 'calls vault to get a token' do
      allow(auth).to receive(:username) { 'foobar' }

      expect(auth.authenticate.name).to eq 'foobar'
    end

    it 'returns a user' do
      allow(auth).to receive(:username) { 'foobar' }

      expect(auth.authenticate).to be_persisted
    end

    it 'updates the token if the user already exists' do
      allow(auth).to receive(:username) { 'someuniquename' }

      u = User.create!(
        name: 'someuniquename',
        auth: 'vault',
        token: 'defg', # instead of abcd
        roles: []
      )

      expect(auth.authenticate.name).to eq 'someuniquename'
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

  describe "#non_shallow_path" do
    let(:request) { double(path: '/v1/something', method: "TEST") }
    let(:district) { create :district }
    let(:heritage) { create :heritage, district: district }

    it "returns non-shallow path if it starts with /v1/heritages" do
      path = auth.send(:non_shallow_path, "/v1/heritages/#{heritage.name}")
      expect(path).to eq "/v1/districts/#{district.name}/heritages/#{heritage.name}"

      path = auth.send(:non_shallow_path, "/v1/heritages/#{heritage.name}/oneoffs")
      expect(path).to eq "/v1/districts/#{district.name}/heritages/#{heritage.name}/oneoffs"
    end

    it "returns path if it doesn't start with /v1/heritages" do
      path = auth.send(:non_shallow_path, "/v1/districts/#{district.name}")
      expect(path).to eq "/v1/districts/#{district.name}"
    end
  end
end
