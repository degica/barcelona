require 'rails_helper'

describe "GET /heritages/:heritage/releases/:version", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  given_auth(GithubAuth) do
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
    end

    it "shows a release" do
      api_request :get, "/v1/heritages/nginx/releases/1"
      expect(response).to be_successful

      release = JSON.load(response.body)["release"]
      expect(release["version"]).to eq 1
      expect(release["description"]).to eq "Create"
      expect(release["data"]).to include("image_name" => "nginx",
                                         "image_tag" => "latest")
    end
  end
end
