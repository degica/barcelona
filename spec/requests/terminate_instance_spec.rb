require 'rails_helper'

describe "POST /districts/:district/terminate_instance", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  before do
  end

  it "terminates an instance" do
    params = {
      container_instance_arn: 'container-instance-arn'
    }
    post "/districts/#{district.name}/terminate_instance", params, auth
    expect(response.status).to eq 204
  end
end
