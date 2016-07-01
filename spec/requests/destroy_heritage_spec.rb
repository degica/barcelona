require 'rails_helper'

describe "DELETE /heritages/:heritage", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  it "updates a heritage" do
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
    api_request :post, "/v1/districts/#{district.name}/heritages", params
    expect(response).to be_success

    api_request :delete, "/v1/heritages/nginx"
    expect(response.status).to eq 204
  end
end
