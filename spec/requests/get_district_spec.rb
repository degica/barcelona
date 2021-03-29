require 'rails_helper'

describe "GET /heritages/:heritage/get_district", type: :request do
  let(:user) { create :user }
  let(:heritage) { create :heritage }

  given_auth(GithubAuth) do
    it "load a district" do
      api_request :get, "/v1/heritages/#{heritage.name}/get_district"
      resp = JSON.parse(response.body)
      expect(response).to be_successful
      expect(resp["district"]["name"]).to eq heritage.district.name
    end
  end
end
