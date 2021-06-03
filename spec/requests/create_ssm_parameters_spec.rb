require 'rails_helper'

describe "POST /v1/districts/:district_name/ssm_parameters", type: :request do
  let(:district) { create(:district) }
  let(:user) { create :user }

  let(:params) do
    {
      name: "PSParameterName",
      value: "PSParameterValue"
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
  end
end
