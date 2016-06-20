require 'rails_helper'

describe "DELETE /apps/:app", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before {Aws.config[:stub_responses] = true}

  it "updates a app" do
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
    expect(response).to be_success

    delete "/v1/apps/nginx", nil, auth
    expect(response.status).to eq 204
  end
end
