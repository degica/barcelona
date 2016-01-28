require 'rails_helper'

describe "POST /districts/:district/launch_instances", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before do
    allow_any_instance_of(District).to receive(:subnets) {
      [double(subnet_id: 'subnet_id')]
    }
    allow_any_instance_of(Aws::EC2::Client).to receive(:run_instances) {
      double(instances: [double(instance_id: 'instance_id')])
    }
  end

  it "launches a instance" do
    params = {
      count: 1,
      instance_type: 't2.micro'
    }
    post "/v1/districts/#{district.name}/launch_instances", params, auth
    expect(response.status).to eq 204
  end
end
