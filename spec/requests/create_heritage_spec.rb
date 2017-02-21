require 'rails_helper'

describe "POST /districts/:district/heritages", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:params) do
    {
      version: version,
      name: "nginx",
      image_name: "nginx",
      image_tag: "latest",
      before_deploy: "echo hello",
      scheduled_tasks: [
        {
          schedule: "rate(1 minute)",
          command: "echo hello"
        }
      ],
      services: [
        {
          name: "web",
          service_type: "web",
          public: true,
          force_ssl: true,
          cpu: 128,
          memory: 256,
          command: "nginx",
          reverse_proxy_image: 'org/custom_revpro:v1.2',
          port_mappings: [
            {container_port: 3333, protocol: "udp", lb_port: 3333 }
          ],
          health_check: {
            protocol: 'tcp',
            port: 1111
          },
          auto_scaling: {
            min_count: 3,
            max_count: 5
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
  end


  shared_examples "create" do
    it "creates a heritage" do
      expect(DeployRunnerJob).to receive(:perform_later)
      api_request(:post, "/v1/districts/#{district.name}/heritages", params)
      expect(response.status).to eq 200
      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["version"]).to eq version
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "latest"
      expect(heritage["before_deploy"]).to eq "echo hello"
      expect(heritage["scheduled_tasks"][0]["schedule"]).to eq "rate(1 minute)"
      expect(heritage["scheduled_tasks"][0]["command"]).to eq "echo hello"
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "nginx"
      expect(heritage["services"][0]["force_ssl"]).to eq true
      expect(heritage["services"][0]["reverse_proxy_image"]).to eq "org/custom_revpro:v1.2"
      expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 3333
      expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 3333
      expect(heritage["services"][0]["port_mappings"][0]["host_port"]).to be_a Integer
      expect(heritage["services"][0]["port_mappings"][0]["protocol"]).to eq "udp"
      expect(heritage["services"][0]["port_mappings"][1]["lb_port"]).to eq 80
      expect(heritage["services"][0]["port_mappings"][1]["container_port"]).to eq 3000
      expect(heritage["services"][0]["port_mappings"][1]["host_port"]).to be_a Integer
      expect(heritage["services"][0]["port_mappings"][1]["protocol"]).to eq "http"
      expect(heritage["services"][0]["port_mappings"][2]["lb_port"]).to eq 443
      expect(heritage["services"][0]["port_mappings"][2]["container_port"]).to eq 3000
      expect(heritage["services"][0]["port_mappings"][2]["host_port"]).to be_a Integer
      expect(heritage["services"][0]["port_mappings"][2]["protocol"]).to eq "https"
      expect(heritage["services"][0]["health_check"]["protocol"]).to eq "tcp"
      expect(heritage["services"][0]["health_check"]["port"]).to eq 1111
      expect(heritage["services"][0]["auto_scaling"]["min_count"]).to eq 3
      expect(heritage["services"][0]["auto_scaling"]["max_count"]).to eq 5
      expect(heritage["services"][0]["hosts"][0]["hostname"]).to eq "awesome-app.degica.com"
      expect(heritage["services"][0]["hosts"][0]["ssl_cert_path"]).to eq "s3://degica-bucket/path/to/cert"
      expect(heritage["services"][0]["hosts"][0]["ssl_key_path"]).to eq "s3://degica-bucket/path/to/key"
    end
  end

  context "when version is 1" do
    let(:version) { 1 }
    it_behaves_like "create"
  end

  context "when version is 2" do
    let(:version) { 2 }
    it_behaves_like "create"
  end
end
