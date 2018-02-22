require 'rails_helper'

describe "POST /review_apps", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:endpoint) {create :endpoint, district: district}
  let(:params) do
    {
      group: "example",
      subject: "https://github.com/org/repo/pull/1111",
      district: district.name,
      base_domain: "review.example.com",
      template: {
        image_name: "nginx",
        image_tag: "v2",
        services: [
          {
            name: "web",
            service_type: "web",
            cpu: 128,
            memory: 256,
            command: "nginx",
            listeners: [
              {
                endpoint: endpoint.name
              }
            ]
          }
        ]
      }
    }
  end

  it "creates a heritage" do
    expect(DeployRunnerJob).to receive(:perform_later)
    api_request(:post, "/v1/review_apps?debug=true", params)
    pp JSON.load(response.body)
    expect(response.status).to eq 200
    heritage = JSON.load(response.body)["heritage"]
  end
end
