require 'rails_helper'

describe "POST /districts/:district/sign_public_key", type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }
  let(:ca_key_pair) { OpenSSL::PKey::RSA.new(1024) }
  let(:public_key) do
    key = OpenSSL::PKey::RSA.new(1024).public_key
    "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
  end

  before do
    allow_any_instance_of(District).to receive(:get_ca_key) { ca_key_pair.to_pem }
  end

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"], public_key: public_key }
    it "returns 403" do
      post "/v1/districts/#{district.name}/sign_public_key", {}, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"], public_key: public_key }
    it "udpates a district" do
      post "/v1/districts/#{district.name}/sign_public_key", {}, auth
      expect(response.status).to eq 200
      resp = JSON.parse(response.body)
      expect(resp["district"]).to be_present
      expect(resp["certificate"]).to be_a String
    end
  end
end
