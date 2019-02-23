require 'rails_helper'

describe "updating a heritage" do
  let(:district) { create :district }
  let(:user) { create :user }

  before do
    params = {
      name: "nginx",
      image_name: "nginx",
      image_tag: "latest",
      before_deploy: "echo hello",
      environment: [
        {name: "ENV_KEY", value: "my value"},
        {name: "SECRET", value_from: "arn"}
      ],
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
        },
        {
          name: "worker",
          command: "rake jobs:work"
        }
      ]
    }
    api_request :post, "/v1/districts/#{district.name}/heritages?debug=true", params
  end

  describe "PATCH /heritages/:heritage", type: :request do
    it "updates a heritage" do
      params = {
        image_tag: "v3",
        before_deploy: nil,
        environment: [
          {name: "ENV2", value: "my value 2"},
          {name: "SECRET", value_from: "arn"}
        ],
        services: [
          {
            name: "web",
            command: "true"
          },
          {
            name: "worker",
            command: "rake jobs:work"
          }
        ]
      }

      expect(DeployRunnerJob).to receive(:perform_later)
      api_request :patch, "/v1/heritages/nginx", params
      expect(response).to be_successful

      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil
      expect(heritage["environment"].count).to eq 2
      expect(heritage["environment"][0]["name"]).to eq "ENV2"
      expect(heritage["environment"][0]["value"]).to eq "my value 2"
      expect(heritage["environment"][0]["value_from"]).to eq nil
      expect(heritage["environment"][1]["name"]).to eq "SECRET"
      expect(heritage["environment"][1]["value"]).to eq nil
      expect(heritage["environment"][1]["value_from"]).to eq "arn"
      web_service = heritage["services"].find { |s| s["name"] == "web" }
      expect(web_service["public"]).to eq true
      expect(web_service["cpu"]).to eq 128
      expect(web_service["memory"]).to eq 256
      expect(web_service["command"]).to eq "true"
      expect(web_service["port_mappings"][0]["lb_port"]).to eq 80
      expect(web_service["port_mappings"][0]["container_port"]).to eq 80
      worker_service = heritage["services"].find { |s| s["name"] == "worker" }
      expect(worker_service["command"]).to eq "rake jobs:work"
    end
  end

  describe "POST /heritages/:heritage/trigger/:token", type: :request do
    let(:district) { create :district }

    it "updates a heritage" do
      params = {
        image_tag: "v3",
        before_deploy: nil,
        services: [
          {
            name: "web",
            command: "true"
          },
          {
            name: "worker",
            command: "rake jobs:work"
          }
        ]
      }

      token = JSON.load(response.body)["heritage"]["token"]

      expect(DeployRunnerJob).to receive(:perform_later)
      api_request :post, "/v1/heritages/nginx/trigger/#{token}", params
      expect(response).to be_successful
      heritage = JSON.load(response.body)["heritage"]

      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil
      web_service = heritage["services"].find { |s| s["name"] == "web" }
      expect(web_service["name"]).to eq "web"
      expect(web_service["public"]).to eq true
      expect(web_service["cpu"]).to eq 128
      expect(web_service["memory"]).to eq 256
      expect(web_service["command"]).to eq "true"
      expect(web_service["port_mappings"][0]["lb_port"]).to eq 80
      expect(web_service["port_mappings"][0]["container_port"]).to eq 80
    end
  end

  describe "with wrong heritage token", type: :request do
    let(:district) { create :district }

    it "returns 404" do
      params = {
        image_tag: "v3",
        before_deploy: nil,
        services: [
          {
            name: "web",
            command: "true"
          },
          {
            name: "worker",
            command: "rake jobs:work"
          }
        ]
      }

      api_request :post, "/v1/heritages/nginx/trigger/wrong-token", params
      expect(response.status).to eq 404
    end
  end

  describe "Adding services" do
    it "updates a heritage" do
      params = {
        image_tag: "v3",
        before_deploy: nil,
        services: [
          {
            name: "web",
            command: "true"
          },
          {
            name: "worker",
            command: "rake jobs:work"
          },
          {
            name: "another-service",
            command: "command"
          }
        ]
      }

      expect(DeployRunnerJob).to receive(:perform_later)
      api_request :patch, "/v1/heritages/nginx", params
      expect(response).to be_successful

      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil

      web_service = heritage["services"].find { |s| s["name"] == "web" }
      expect(web_service["public"]).to eq true
      expect(web_service["cpu"]).to eq 128
      expect(web_service["memory"]).to eq 256
      expect(web_service["command"]).to eq "true"
      expect(web_service["port_mappings"][0]["lb_port"]).to eq 80
      expect(web_service["port_mappings"][0]["container_port"]).to eq 80

      worker_service = heritage["services"].find { |s| s["name"] == "worker" }
      expect(worker_service["command"]).to eq "rake jobs:work"

      another_service = heritage["services"].find { |s| s["name"] == "another-service" }
      expect(another_service["command"]).to eq "command"
    end
  end

  describe "Deleting services" do
    it "updates a heritage" do
      params = {
        image_tag: "v3",
        before_deploy: nil,
        services: [
          {
            name: "web",
            command: "true"
          }
        ]
      }

      expect(DeployRunnerJob).to receive(:perform_later)
      api_request :patch, "/v1/heritages/nginx", params
      expect(response).to be_successful

      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["services"].count).to eq 1
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "true"
      expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 80
    end
  end
end
