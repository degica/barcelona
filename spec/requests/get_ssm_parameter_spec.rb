require 'rails_helper'

describe "GET /v1/districts/:district_name/get_ssm_parameter/:name", type: :request do
  let(:district) { create(:district) }
  let(:user) { create :user }

  given_auth(VaultAuth) do
    before do
      allow_any_instance_of(VaultAuth).to receive(:authenticate) { user }
      allow_any_instance_of(VaultAuth).to receive(:authorize_action) { true }
    end

    it "when ssm parameter exits" do
      api_request :get, "/v1/districts/#{district.name}/get_ssm_parameter/#{district.name}"
      body = JSON.parse(response.body)

      expect(body["name"]).to eq "PSParameterName"
      expect(body["value"]).to eq "PSParameterValue"
    end

    it "when ssm parameter doesn't exit" do
      ssm = district.aws.ssm
      ssm_parameter_name = "test"

      ssm.stub_responses(:get_parameter, Aws::SSM::Errors::ParameterNotFound.new(nil, nil, nil))
      allow_any_instance_of(AwsAccessor).to receive(:ssm).and_return(ssm)

      ssm_path = "/barcelona/#{district.name}/#{ssm_parameter_name}"
      api_request :get, "/v1/districts/#{district.name}/get_ssm_parameter/#{ssm_parameter_name}"

      expect(response.status).to eq 400
      expect(response.body).to eq "The ssm_path #{ssm_path} does not exist in district #{district.name}".to_json
    end
  end
end
