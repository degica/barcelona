require 'rails_helper'

describe "POST /districts/:district/endpoints", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }

  given_auth(GithubAuth) do
    it "creates an endpoint" do
      allow_any_instance_of(CloudFormation::Executor).to receive(:outputs) {
        {"DNSName" => "dns.name"}
      }
      params = {
        name: "my-endpoint",
        public: true,
        ssl_policy: 'modern',
        certificate_id: 'certificate_id'
      }
      api_request(:post, "/v1/districts/#{district.name}/endpoints", params)
      expect(response.status).to eq 200
      endpoint = JSON.load(response.body)["endpoint"]
      expect(endpoint["name"]).to eq "#{district.name}-my-endpoint"
      expect(endpoint["public"]).to eq true
      expect(endpoint["certificate_id"]).to eq 'certificate_id'
      expect(endpoint["ssl_policy"]).to eq 'modern'
      expect(endpoint["dns_name"]).to eq "dns.name"
    end

    it "creates same endpoint name in two district" do
      allow_any_instance_of(CloudFormation::Executor).to receive(:outputs) {
        {"DNSName" => "dns.name"}
      }
      params = {
        name: "my-endpoint",
        public: true,
        ssl_policy: 'modern',
        certificate_id: 'certificate_id'
      }
      api_request(:post, "/v1/districts/#{district.name}/endpoints", params)
      expect(response.status).to eq 200

      # create same name in other district
      district2 = create :district
      api_request(:post, "/v1/districts/#{district2.name}/endpoints", params)
      expect(response.status).to eq 200

      endpoint = JSON.load(response.body)["endpoint"]
      expect(endpoint["name"]).to eq "#{district2.name}-my-endpoint"
      expect(endpoint["public"]).to eq true
      expect(endpoint["certificate_id"]).to eq 'certificate_id'
      expect(endpoint["ssl_policy"]).to eq 'modern'
      expect(endpoint["dns_name"]).to eq "dns.name"
    end

    it "it should failed if the endpoint name is same" do
      allow_any_instance_of(CloudFormation::Executor).to receive(:outputs) {
        {"DNSName" => "dns.name"}
      }

      district = create :district, name: "staging"
      district.endpoints.create(name: "staging-blue-green")
      district2 = create :district, name: "staging-blue"

      params = {
        name: "green",
        public: true,
        ssl_policy: 'modern',
        certificate_id: 'certificate_id'
      }

      api_request(:post, "/v1/districts/#{district2.name}/endpoints", params)
      expect(response.status).to eq 422
    end
  end
end
