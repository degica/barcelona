require 'rails_helper'

describe "updating a app" do
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
    post "/v1/districts/#{district.name}/apps", params, auth
  end

  describe "PATCH /apps/:app", type: :request do
    it "updates a app" do
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
      patch "/v1/apps/nginx", params, auth
      expect(response).to be_success

      app = JSON.load(response.body)["app"]
      expect(app["name"]).to eq "nginx"
      expect(app["image_name"]).to eq "nginx"
      expect(app["image_tag"]).to eq "v3"
      expect(app["before_deploy"]).to eq nil
      expect(app["services"][0]["name"]).to eq "web"
      expect(app["services"][0]["public"]).to eq true
      expect(app["services"][0]["cpu"]).to eq 128
      expect(app["services"][0]["memory"]).to eq 256
      expect(app["services"][0]["command"]).to eq "true"
      expect(app["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(app["services"][0]["port_mappings"][0]["container_port"]).to eq 80
      expect(app["services"][1]["name"]).to eq "worker"
      expect(app["services"][1]["command"]).to eq "rake jobs:work"
    end
  end

  describe "POST /apps/:app/trigger/:token", type: :request do
    let(:district) { create :district }

    it "updates a app" do
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

      token = JSON.load(response.body)["app"]["token"]

      expect(DeployRunnerJob).to receive(:perform_later)
      post "/v1/apps/nginx/trigger/#{token}", params
      expect(response).to be_success
      app = JSON.load(response.body)["app"]

      expect(app["name"]).to eq "nginx"
      expect(app["image_name"]).to eq "nginx"
      expect(app["image_tag"]).to eq "v3"
      expect(app["before_deploy"]).to eq nil
      web_service = app["services"].find { |s| s["name"] == "web" }
      expect(web_service["name"]).to eq "web"
      expect(web_service["public"]).to eq true
      expect(web_service["cpu"]).to eq 128
      expect(web_service["memory"]).to eq 256
      expect(web_service["command"]).to eq "true"
      expect(web_service["port_mappings"][0]["lb_port"]).to eq 80
      expect(web_service["port_mappings"][0]["container_port"]).to eq 80
    end
  end

  describe "with wrong app token", type: :request do
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

      post "/v1/apps/nginx/trigger/wrong-token", params
      expect(response.status).to eq 404
    end
  end

  describe "Adding services" do
    it "updates a app" do
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
      patch "/v1/apps/nginx", params, auth
      expect(response).to be_success

      app = JSON.load(response.body)["app"]
      expect(app["name"]).to eq "nginx"
      expect(app["image_name"]).to eq "nginx"
      expect(app["image_tag"]).to eq "v3"
      expect(app["before_deploy"]).to eq nil

      web_service = app["services"].find { |s| s["name"] == "web" }
      expect(web_service["public"]).to eq true
      expect(web_service["cpu"]).to eq 128
      expect(web_service["memory"]).to eq 256
      expect(web_service["command"]).to eq "true"
      expect(web_service["port_mappings"][0]["lb_port"]).to eq 80
      expect(web_service["port_mappings"][0]["container_port"]).to eq 80

      worker_service = app["services"].find { |s| s["name"] == "worker" }
      expect(worker_service["command"]).to eq "rake jobs:work"

      another_service = app["services"].find { |s| s["name"] == "another-service" }
      expect(another_service["command"]).to eq "command"
    end
  end

  describe "Deleting services" do
    it "updates a app" do
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
      patch "/v1/apps/nginx", params, auth
      expect(response).to be_success

      app = JSON.load(response.body)["app"]
      expect(app["services"].count).to eq 1
      expect(app["services"][0]["name"]).to eq "web"
      expect(app["services"][0]["public"]).to eq true
      expect(app["services"][0]["cpu"]).to eq 128
      expect(app["services"][0]["memory"]).to eq 256
      expect(app["services"][0]["command"]).to eq "true"
      expect(app["services"][0]["port_mappings"][0]["lb_port"]).to eq 80
      expect(app["services"][0]["port_mappings"][0]["container_port"]).to eq 80
    end
  end
end
