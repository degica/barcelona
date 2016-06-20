require 'rails_helper'

describe "DELETE /apps/:app/env_vars", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before {Aws.config[:stub_responses] = true}
  before do
    params = {
      name: "nginx",
      image_name: "nginx",
      image_tag: "latest",
      before_deploy: "echo hello",
      env_vars: {
        "RAILS_ENV" => "production"
      },
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
    expect(response).to be_success
  end

  it "deletes app's environment variables" do
    params = {
      env_keys: ["RAILS_ENV"]
    }

    expect(DeployRunnerJob).to receive(:perform_later)
    delete "/v1/apps/nginx/env_vars", params, auth
    expect(response).to be_success

    app = JSON.load(response.body)["app"]
    expect(app["name"]).to eq "nginx"
    expect(app["image_name"]).to eq "nginx"
    expect(app["image_tag"]).to eq "latest"
    expect(app["before_deploy"]).to eq "echo hello"
    expect(app["services"][0]["name"]).to eq "web"
    expect(app["services"][0]["public"]).to eq true
    expect(app["services"][0]["cpu"]).to eq 128
    expect(app["services"][0]["memory"]).to eq 256
    expect(app["services"][0]["command"]).to eq nil
    expect(app["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
    expect(app["services"][0]["port_mappings"][0]["container_port"]).to eq 80

    expect(app["env_vars"]).to be_blank
  end
end
