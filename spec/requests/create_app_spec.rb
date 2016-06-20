require 'rails_helper'

describe "POST /districts/:district/apps", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token, "Content-Type" => "application/json", "Accept" => "application/json"} }
  let(:district) { create :district }

  it "creates a app" do
    params = {
      name: "nginx",
      image_name: "nginx",
      image_tag: "latest",
      before_deploy: "echo hello",
      services: [
        {
          name: "web",
          service_type: "web",
          public: true,
          force_ssl: true,
          cpu: 128,
          memory: 256,
          reverse_proxy_image: 'org/custom_revpro:v1.2',
          port_mappings: [
            {container_port: 3333, protocol: "udp", lb_port: 3333 }
          ],
          health_check: {
            protocol: 'tcp',
            port: 1111
          },
          hosts: [
            {
              hostname: 'awesome-app.degica.com',
              ssl_cert_path: 's3://degica-bucket/path/to/cert',
              ssl_key_path: 's3://degica-bucket/path/to/key'
            }
          ]
        }
      ]
    }
    expect(DeployRunnerJob).to receive(:perform_later)
    api_request(:post, "/v1/districts/#{district.name}/apps", params)
    expect(response.status).to eq 200
    app = JSON.load(response.body)["app"]
    expect(app["name"]).to eq "nginx"
    expect(app["image_name"]).to eq "nginx"
    expect(app["image_tag"]).to eq "latest"
    expect(app["before_deploy"]).to eq "echo hello"
    expect(app["services"][0]["name"]).to eq "web"
    expect(app["services"][0]["public"]).to eq true
    expect(app["services"][0]["cpu"]).to eq 128
    expect(app["services"][0]["memory"]).to eq 256
    expect(app["services"][0]["force_ssl"]).to eq true
    expect(app["services"][0]["reverse_proxy_image"]).to eq "org/custom_revpro:v1.2"
    expect(app["services"][0]["port_mappings"][0]["lb_port"]).to eq 3333
    expect(app["services"][0]["port_mappings"][0]["container_port"]).to eq 3333
    expect(app["services"][0]["port_mappings"][0]["host_port"]).to be_a Integer
    expect(app["services"][0]["port_mappings"][0]["protocol"]).to eq "udp"
    expect(app["services"][0]["port_mappings"][1]["lb_port"]).to eq 80
    expect(app["services"][0]["port_mappings"][1]["container_port"]).to eq 3000
    expect(app["services"][0]["port_mappings"][1]["host_port"]).to be_a Integer
    expect(app["services"][0]["port_mappings"][1]["protocol"]).to eq "http"
    expect(app["services"][0]["port_mappings"][2]["lb_port"]).to eq 443
    expect(app["services"][0]["port_mappings"][2]["container_port"]).to eq 3000
    expect(app["services"][0]["port_mappings"][2]["host_port"]).to be_a Integer
    expect(app["services"][0]["port_mappings"][2]["protocol"]).to eq "https"
    expect(app["services"][0]["health_check"]["protocol"]).to eq "tcp"
    expect(app["services"][0]["health_check"]["port"]).to eq 1111
    expect(app["services"][0]["hosts"][0]["hostname"]).to eq "awesome-app.degica.com"
    expect(app["services"][0]["hosts"][0]["ssl_cert_path"]).to eq "s3://degica-bucket/path/to/cert"
    expect(app["services"][0]["hosts"][0]["ssl_key_path"]).to eq "s3://degica-bucket/path/to/key"
  end
end
