require 'rails_helper'

describe SignSSHKey, type: :model do
  subject { described_class.new(user, ca_key) }

  let(:user) { create :user, public_key: public_key }
  let(:ca_key) { OpenSSL::PKey::RSA.new(1024).to_pem }
  let(:public_key) do
    key = OpenSSL::PKey::RSA.new(1024).public_key
    "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
  end

  describe "#sign" do
    context "when user's public key doesn't exist" do
      let(:public_key) { nil }
      it "raises an error" do
        expect{subject.sign}.to raise_error ArgumentError
      end
    end

    context "when CA key doesn't exist" do
      let(:ca_key) { nil }
      it "raises an error" do
        expect{subject.sign}.to raise_error ArgumentError
      end
    end

    it "signs user's public key" do
      expect(subject).to receive(:spawn).
                           with(kind_of(String), err: '/dev/null', out: '/dev/null').
                           and_call_original
      expect(subject.sign).to be_a String
    end
  end
end
