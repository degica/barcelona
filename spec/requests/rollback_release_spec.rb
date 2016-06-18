require "rails_helper"

describe "POST /apps/:app/releases/:version/rollback", type: :request do
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
    patch "/v1/apps/nginx", {"image_tag" => "v111"}, auth
  end

  it "rolls back to the specified version" do
    post "/v1/apps/nginx/releases/1/rollback", nil, auth
    expect(response).to be_success

    release = JSON.load(response.body)["release"]
    expect(release["version"]).to eq 3
    expect(release["description"]).to eq "Rolled back to version 1"
    expect(release["data"]).to include("image_name" => "nginx", "image_tag" => "latest")
  end
end
