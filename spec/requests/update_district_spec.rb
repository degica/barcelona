require 'rails_helper'

describe "PATCH /districts/:district", type: :request do
  let(:district) { create :district }

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 403" do
      api_request :patch, "/v1/districts/#{district.name}"
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "udpates a district" do
      api_request :patch, "/v1/districts/#{district.name}"
      expect(response.status).to eq 200
    end
  end
end
