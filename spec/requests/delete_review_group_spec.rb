require "rails_helper"

describe "DELETE /v1/review_groups/:review_group", type: :request do
  let(:user) { create :user, roles: roles }
  let(:review_group) { create :review_group }

  context "when developer uer" do
    let(:roles) { ["developer"] }

    it "fails" do
      api_request(:delete, "/v1/review_groups/#{review_group.name}")
      expect(response.status).to eq 403
    end
  end

  context "when admin uer" do
    let(:roles) { ["admin"] }

    it "deletes a review group" do
      api_request(:delete, "/v1/review_groups/#{review_group.name}")
      expect(response.status).to eq 204
    end
  end
end
