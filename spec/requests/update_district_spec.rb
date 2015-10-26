require 'rails_helper'

describe "PATCH /districts/:district", :vcr, type: :request do
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before do
    allow_any_instance_of(District).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
  end

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 401" do
      patch "/districts/#{district.name}", {}, auth
      expect(response.status).to eq 401
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "udpates a district" do
      patch "/districts/#{district.name}", {}, auth
      expect(response.status).to eq 200
    end
  end
end
