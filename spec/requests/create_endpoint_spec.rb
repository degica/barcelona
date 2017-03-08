require 'rails_helper'

describe "POST /districts/:district/endpoints", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  it "creates an endpoint" do
    allow_any_instance_of(CloudFormation::Executor).to receive(:outputs) {
      {"DNSName" => "dns.name"}
    }
    params = {
      name: "my-endpoint",
      public: true,
      certificate_id: 'certificate_id'
    }
    api_request(:post, "/v1/districts/#{district.name}/endpoints", params)
    expect(response.status).to eq 200
    endpoint = JSON.load(response.body)["endpoint"]
    expect(endpoint["name"]).to eq "my-endpoint"
    expect(endpoint["public"]).to eq true
    expect(endpoint["certificate_id"]).to eq 'certificate_id'
    expect(endpoint["dns_name"]).to eq "dns.name"
  end
end
