require 'rails_helper'

describe "GET /districts/:district", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let!(:plugin) { create :plugin, district: district }

  before do
    expect_any_instance_of(Aws::CloudFormation::Client).to receive(:describe_stacks) do
      double(stacks: [double(stack_status: "CREATE_COMPLETE")])
    end
  end

  it "shows a district" do
    api_request :get, "/v1/districts/#{district.name}"
    expect(response.status).to eq 200
    district = JSON.load(response.body)["district"]
    expect(district["stack_status"]).to eq "CREATE_COMPLETE"
    expect(district["plugins"]).to eq([{"name" => plugin.name,
                                        "attributes" => JSON.load(plugin.plugin_attributes.to_json)}])
  end
end
