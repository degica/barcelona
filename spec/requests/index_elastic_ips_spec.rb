require 'rails_helper'

describe "GET /districts/:district/elastic_ips", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "allocates elastic IP" do
    params = {}
    get "/v1/districts/#{district.name}/elastic_ips", params, auth
    expect(response.status).to eq 200
  end
end
