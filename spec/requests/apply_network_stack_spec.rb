require "rails_helper"

describe "POST /districts/:district/apply_stack" do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 403" do
      post "/v1/districts/#{district.name}/apply_stack", {}, auth
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "udpates a district" do
      post "/v1/districts/#{district.name}/apply_stack", {}, auth
      expect(response.status).to eq 202
    end
  end
end
