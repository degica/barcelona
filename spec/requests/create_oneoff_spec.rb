require 'rails_helper'

describe "POST /heritages/:heritage/oneoffs", type: :request do
  let(:user) { create :user }
  let(:heritage) { create :heritage }

  it "creates a oneoff task" do
    expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
      double(tasks: [double(task_arn: 'arn', containers: [])])
    end

    params = {
      command: "rake db:migrate",
      image_tag: "v100"
    }
    api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
    expect(response).to be_success
    oneoff = JSON.load(response.body)["oneoff"]
    expect(oneoff["task_arn"]).to eq "arn"
    expect(oneoff["command"]).to eq "rake db:migrate"
  end
end
