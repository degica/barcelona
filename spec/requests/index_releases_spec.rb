require 'rails_helper'

describe "GET /heritages/:heritage/releases", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  before do
    params = {
      name: "nginx",
      image_name: "nginx",
      image_tag: "latest",
      before_deploy: "echo hello",
      services: [
        {
          name: "web",
          public: true,
          cpu: 128,
          memory: 256,
          command: "nginx",
          port_mappings: [
            {
              lb_port: 80,
              container_port: 80
            }
          ]
        }
      ]
    }
    api_request :post, "/v1/districts/#{district.name}/heritages", params
    api_request :patch, "/v1/heritages/nginx"
  end

  it "shows a release" do
    api_request :get, "/v1/heritages/nginx/releases"
    expect(response).to be_success

    releases = JSON.load(response.body)["releases"]
    expect(releases[0]["version"]).to eq 2
    expect(releases[1]["version"]).to eq 1
  end
end
