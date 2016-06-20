require 'rails_helper'

describe "GET /apps/:app/releases", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
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
          port_mappings: [
            {
              lb_port: 80,
              container_port: 80
            }
          ]
        }
      ]
    }
    post "/v1/districts/#{district.name}/apps", params, auth
    patch "/v1/apps/nginx", nil, auth
  end

  it "shows a release" do
    get "/v1/apps/nginx/releases", nil, auth
    expect(response).to be_success

    releases = JSON.load(response.body)["releases"]
    expect(releases[0]["version"]).to eq 2
    expect(releases[1]["version"]).to eq 1
  end
end
