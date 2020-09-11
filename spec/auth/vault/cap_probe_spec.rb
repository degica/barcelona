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
  end

  describe '#retrieve_capabilites' do
  end

end
