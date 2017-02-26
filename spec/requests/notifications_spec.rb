require 'rails_helper'

describe "notifications endpoint", type: :request do
  let(:district) { create :district }

  describe "POST /districts/:district_id/notifications" do
    let(:slack_endpoint) { "https://hooks.slack.com/services/adfjkadsa/dfsadfas" }
    let(:params) do
      {
        target: "slack",
        endpoint: slack_endpoint
      }
    end

    context "when a user is a developer" do
      let(:user) { create :user, roles: ["developer"] }
      it "returns 403" do
        api_request :post, "/v1/districts/#{district.name}/notifications", params
        expect(response.status).to eq 403
      end
    end

    context "when a user is an admin" do
      let(:user) { create :user, roles: ["admin"] }
      it "creates a notification" do
        api_request :post, "/v1/districts/#{district.name}/notifications", params
        expect(response.status).to eq 201

        body = JSON.load(response.body)
        expect(body["notification"]["target"]).to eq "slack"
        expect(body["notification"]["endpoint"]).to eq slack_endpoint
      end
    end
  end

  describe "PATCH /districts/:district_id/notifications/:id" do
    let(:slack_endpoint) { "https://hooks.slack.com/services/adfjkadsa/dfsadfas" }
    let!(:notification) { create :notification, district: district }
    let(:params) do
      {
        endpoint: slack_endpoint
      }
    end

    context "when a user is a developer" do
      let(:user) { create :user, roles: ["developer"] }
      it "returns 403" do
        api_request :patch, "/v1/districts/#{district.name}/notifications/#{notification.id}", params
        expect(response.status).to eq 403
      end
    end

    context "when a user is an admin" do
      let(:user) { create :user, roles: ["admin"] }
      it "updates a notification" do
        api_request :patch, "/v1/districts/#{district.name}/notifications/#{notification.id}", params
        expect(response.status).to eq 200

        body = JSON.load(response.body)
        expect(body["notification"]["target"]).to eq "slack"
        expect(body["notification"]["endpoint"]).to eq slack_endpoint
      end
    end
  end

  describe "GET /districts/:district_id/notifications/:id" do
    let!(:notification) { create :notification, district: district }
    let(:user) { create :user, roles: ["admin"] }

    it "shows a notification" do
      api_request :get, "/v1/districts/#{district.name}/notifications/#{notification.id}", nil
      expect(response.status).to eq 200

      body = JSON.load(response.body)
      expect(body["notification"]["target"]).to eq notification.target
      expect(body["notification"]["endpoint"]).to eq notification.endpoint
    end
  end

  describe "DELETE /districts/:district_id/notifications/:id" do
    let!(:notification) { create :notification, district: district }

    context "when a user is a developer" do
      let(:user) { create :user, roles: ["developer"] }
      it "returns 403" do
        api_request :delete, "/v1/districts/#{district.name}/notifications/#{notification.id}", nil
        expect(response.status).to eq 403
      end
    end

    context "when a user is an admin" do
      let(:user) { create :user, roles: ["admin"] }
      it "deletes a notification" do
        api_request :delete, "/v1/districts/#{district.name}/notifications/#{notification.id}", nil
        expect(response.status).to eq 204
      end
    end
  end
end
