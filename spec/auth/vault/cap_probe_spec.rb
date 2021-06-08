require "rails_helper"

describe Vault::CapProbe do
  describe '#prefix' do
    it 'returns empty string if not set' do
      cp = Vault::CapProbe.new('', '', nil)
      expect(cp.prefix).to eq ''
    end

    it 'returns string if set' do
      cp = Vault::CapProbe.new('', '', 'abc')
      expect(cp.prefix).to eq '/abc'
    end
  end

  describe '#authorized?' do
    let(:cp) { Vault::CapProbe.new('', '', 'abc') }

    it 'always yes if root' do
      allow(cp).to receive(:retrieve_capabilites) { ['root'] }
      expect(cp.authorized?('/abcd', 'OPTIONS')).to eq true
    end

    it 'looks up method' do
      stub_const("Vault::CapProbe::METHOD_MAP", {
                   'PUSH' => 'push'
                 })

      allow(cp).to receive(:retrieve_capabilites) { ['push'] }
      expect(cp.authorized?('/abcd', 'PUSH')).to eq true
    end

    it 'false if not authorized' do
      stub_const("Vault::CapProbe::METHOD_MAP", {
                   'PULL' => 'pull'
                 })

      allow(cp).to receive(:retrieve_capabilites) { ['push'] }
      expect(cp.authorized?('/abcd', 'PULL')).to eq false
    end

    it 'throws on if method not found' do
      stub_const("Vault::CapProbe::METHOD_MAP", {
                   'PUSH' => 'push'
                 })

      allow(cp).to receive(:retrieve_capabilites) { ['poke'] }
      expect { cp.authorized?('/abcd', 'POKE') }.to raise_error ExceptionHandler::Unauthorized
    end
  end

  describe '#retrieve_capabilites' do
    it 'makes a call to vault to get the capabilities array' do
      stub_request(:post, "http://vault-location/v1/sys/capabilities-self").
           with(headers: {"X-Vault-Token" => "vault-token"},
                body: {paths: ["secret/Barcelona/testorg/testpath"]}.to_json
               ).
           to_return(body: {capabilities: ["poke"]}.to_json)

      cp = Vault::CapProbe.new(URI('http://vault-location'), 'vault-token', 'testorg')
      expect(cp.retrieve_capabilites('/testpath')).to eq ['poke']
    end
  end
end
