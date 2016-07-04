require 'rails_helper'

describe "GET /districts", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let!(:district) { create :district }

  it "lists districts" do
    get "/v1/districts", nil, auth
    expect(response.status).to eq 200
    districts = JSON.load(response.body)["districts"]
    expect(districts.count).to eq 1
  end
end
