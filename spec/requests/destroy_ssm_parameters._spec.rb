require 'rails_helper'

describe "POST /v1/districts/:district_name/ssm_parameters", type: :request do
  let(:district) { create(:district) }
  let(:user) { create :user }

  given_auth(VaultAuth) do
    before do
      allow_any_instance_of(VaultAuth).to receive(:authenticate) { user }
      allow_any_instance_of(VaultAuth).to receive(:authorize_action) { true }
    end

    it "destroy ssm parameter" do
      name = "test_parameter"
      api_request :delete, "/v1/districts/#{district.name}/ssm_parameters/#{name}"
      expect(response).to be_successful
      body = JSON.parse(response.body)
      expect(body["deleted_parameters"]).to eq []
      expect(body["invalid_parameters"]).to eq []
    end
  end
end
