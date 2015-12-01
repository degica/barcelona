require 'rails_helper'

describe "POST /districts/:district/heritages", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "creates a heritage" do
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
          reverse_proxy_image: 'org/custom_revpro:v1.2',
          port_mappings: [
            {container_port: 80,   protocol: "http" },
            {container_port: 3333, protocol: "udp", lb_port: 3333 }
          ]
        }
      ]
    }
    expect(DeployRunnerJob).to receive(:perform_later)
    post "/v1/districts/#{district.name}/heritages", params, auth
    expect(response.status).to eq 200
    heritage = JSON.load(response.body)["heritage"]
    expect(heritage["name"]).to eq "nginx"
    expect(heritage["image_name"]).to eq "nginx"
    expect(heritage["image_tag"]).to eq "latest"
    expect(heritage["before_deploy"]).to eq "echo hello"
    expect(heritage["services"][0]["name"]).to eq "web"
    expect(heritage["services"][0]["public"]).to eq true
    expect(heritage["services"][0]["cpu"]).to eq 128
    expect(heritage["services"][0]["memory"]).to eq 256
    expect(heritage["services"][0]["reverse_proxy_image"]).to eq "org/custom_revpro:v1.2"
    expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
    expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 80
    expect(heritage["services"][0]["port_mappings"][0]["host_port"]).to be_a Integer
    expect(heritage["services"][0]["port_mappings"][0]["protocol"]).to eq "http"
    expect(heritage["services"][0]["port_mappings"][1]["lb_port"]).to eq 443
    expect(heritage["services"][0]["port_mappings"][1]["container_port"]).to eq 80
    expect(heritage["services"][0]["port_mappings"][1]["host_port"]).to be_a Integer
    expect(heritage["services"][0]["port_mappings"][1]["protocol"]).to eq "https"
    expect(heritage["services"][0]["port_mappings"][2]["lb_port"]).to eq 3333
    expect(heritage["services"][0]["port_mappings"][2]["container_port"]).to eq 3333
    expect(heritage["services"][0]["port_mappings"][2]["host_port"]).to be_a Integer
    expect(heritage["services"][0]["port_mappings"][2]["protocol"]).to eq "udp"
  end
end
