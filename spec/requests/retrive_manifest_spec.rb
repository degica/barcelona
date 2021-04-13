require 'rails_helper'

describe "retrieve a manifest" do
  let(:district) { create :district }
  let(:user) { create :user }

  given_auth(GithubAuth) do
    before do
      params = {
        name: "nginx",
        image_name: "quay.io/degica/barcelona",
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

    describe "PATCH /heritages/:heritage/retrieve_manifest", type: :request do
      it "retrieve a manifest" do
        params = {
          user: "userId",
          password: "password"
        }

        retrieve_manifest = instance_double(RetrieveQuayManifest)
        response = double(:response)
        allow(response).to receive(:body).and_return({schemaVersion: "v1"})
        allow(response).to receive(:successful?).and_return(true)

        allow(RetrieveQuayManifest).to receive(:new).and_return(retrieve_manifest)
        allow(retrieve_manifest).to receive(:process).and_return(response)


        api_request :post, "/v1/heritages/nginx/retrieve_manifest", params
        expect(response).to be_successful
        expect(response.body).not_to be_empty
      end
    end
  end
end
