require 'rails_helper'

describe "DELETE /v1/:review_group/apps/:review_app", type: :request do
  let(:user) { create :user }
  let(:review_group) { create(:review_group) }
  let(:review_app) { create(:review_app, review_group: review_group) }

  it "creates a heritage" do
    allow(DeployRunnerJob).to receive(:perform_later)
    api_request(:delete, "/v1/review_groups/#{review_group.name}/apps/#{review_app.subject}")
    expect(response.status).to eq 204
  end
end
