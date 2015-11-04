require 'rails_helper'

describe "GET /districts/:district", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "allocates elastic IP" do
    params = {}
    post "/districts/#{district.name}/allocate_elastic_ip", params, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["elastic_ip"]
    expect(body["allocation_id"]).to be_present
  end

  it "preserve an exisiting EIP" do
    params = {
      allocation_id: 'allocation_id'
    }
    post "/districts/#{district.name}/allocate_elastic_ip", params, auth
    expect(response.status).to eq 200
    body = JSON.load(response.body)["elastic_ip"]
    expect(body["allocation_id"]).to eq "allocation_id"
  end
end
