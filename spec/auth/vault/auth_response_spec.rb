require "rails_helper"

describe Vault::AuthResponse do
  describe '#username' do
    it 'returns the username' do
      resp = double('HTTPResponse', body: '{ "auth": { "metadata": { "username": "john" } } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.username).to eq 'john'
    end

    it 'returns nil if no username' do
      resp = double('HTTPResponse', body: '{ "auth": { "metadata": { } } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.username).to be_nil
    end
  end

  describe '#org' do
    it 'returns the org' do
      resp = double('HTTPResponse', body: '{ "auth": { "metadata": { "org": "degica-test" } } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.org).to eq 'degica-test'
    end

    it 'returns nil if no org' do
      resp = double('HTTPResponse', body: '{ "auth": { "metadata": { } } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.org).to be_nil
    end
  end

  describe '#policies' do
    it 'returns the policies' do
      resp = double('HTTPResponse', body: '{ "auth": { "policies": ["white_rabbit"] } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.policies).to eq ['white_rabbit']
    end

    it 'returns nil if no policies' do
      resp = double('HTTPResponse', body: '{ "auth": { } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.policies).to be_nil
    end
  end

  describe '#client_token' do
    it 'returns the token' do
      resp = double('HTTPResponse', body: '{ "auth": { "client_token": "abcdefg" } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.client_token).to eq 'abcdefg'
    end

    it 'returns nil if no token' do
      resp = double('HTTPResponse', body: '{ "auth": { } }')
      ar = Vault::AuthResponse.new(resp)
      expect(ar.client_token).to be_nil
    end
  end
end
