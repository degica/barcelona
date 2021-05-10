require 'rails_helper'

describe "POST /v1/districts/:district_name/ssm_parameters", type: :request do
  let(:district) { create(:district) }
  let(:user) { create :user }

  let(:params) do
    {
      name: "PSParameterName",
      value: "PSParameterValue",
      type: "SecureString",
    }
  end

  given_auth(VaultAuth) do
    before do
      allow_any_instance_of(VaultAuth).to receive(:authenticate) { user }
      allow_any_instance_of(VaultAuth).to receive(:authorize_action) { true }
    end

    it "create ssm parameter" do
      api_request :post, "/v1/districts/#{district.name}/ssm_parameters", params
      expect(response.status).to eq 200
    end

    it "when ssm type is not valid" do
      type = "hoge"
      params[:type] = type

      api_request :post, "/v1/districts/#{district.name}/ssm_parameters" , params
      expect(response.status).to eq 500
      body = JSON.parse(response.body)
      expect(body["error"]).to eq "Type #{type} is not in [\"String\", \"StringList\", \"SecureString\"]"
    end
  end
end
