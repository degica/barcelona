require 'rails_helper'

describe "DELETE /districts/:district", type: :request do
  let(:district) { create :district }

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 403" do
      api_request :delete, "/v1/districts/#{district.name}"
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "destroys a district" do
      api_request :delete, "/v1/districts/#{district.name}"
      expect(response.status).to eq 204
    end
  end
end
