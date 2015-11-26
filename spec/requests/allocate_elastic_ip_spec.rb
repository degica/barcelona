require 'rails_helper'

describe "POST /districts/:district/elastic_ips", type: :request do
  let(:user) { create :user, roles: ["admin"] }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "allocates elastic IP" do
    params = {}
    post "/v1/districts/#{district.name}/elastic_ips", params, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["elastic_ip"]
    expect(body["allocation_id"]).to be_present
  end

  it "preserve an exisiting EIP" do
    params = {
      allocation_id: 'allocation_id'
    }
    post "/v1/districts/#{district.name}/elastic_ips", params, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["elastic_ip"]
    expect(body["allocation_id"]).to eq "allocation_id"
  end
end
