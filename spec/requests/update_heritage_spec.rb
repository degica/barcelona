require 'rails_helper'

describe "updating a heritage" do
  let(:district) { create :district }
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }

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
        },
        {
          name: "worker",
          command: "rake jobs:work"
        }
      ]
    }
    post "/v1/districts/#{district.name}/heritages", params, auth
  end

  describe "PATCH /heritages/:heritage", type: :request do
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

      expect(DeployRunnerJob).to receive(:perform_later)
      patch "/v1/heritages/nginx", params, auth
      expect(response).to be_success

      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "true"
      expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 80
      expect(heritage["services"][1]["name"]).to eq "worker"
      expect(heritage["services"][1]["command"]).to eq "rake jobs:work"
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
      post "/v1/heritages/nginx/trigger/#{token}", params
      expect(response).to be_success
      heritage = JSON.load(response.body)["heritage"]

      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "true"
      expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 80
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

      post "/v1/heritages/nginx/trigger/wrong-token", params
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
      patch "/v1/heritages/nginx", params, auth
      expect(response).to be_success

      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "v3"
      expect(heritage["before_deploy"]).to eq nil
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "true"
      expect(heritage["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(heritage["services"][0]["port_mappings"][0]["container_port"]).to eq 80
      expect(heritage["services"][1]["name"]).to eq "worker"
      expect(heritage["services"][1]["command"]).to eq "rake jobs:work"
      expect(heritage["services"][2]["name"]).to eq "another-service"
      expect(heritage["services"][2]["command"]).to eq "command"
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
      patch "/v1/heritages/nginx", params, auth
      expect(response).to be_success

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
