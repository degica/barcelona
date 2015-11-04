require 'rails_helper'

describe "POST /districts/:district/launch_instances", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before do
    allow_any_instance_of(DistrictSection).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
  end

  it "launches a instance" do
    params = {
      count: 1,
      instance_type: 't2.micro'
    }
    post "/districts/#{district.name}/launch_instances", params, auth
    expect(response.status).to eq 204
  end
end
