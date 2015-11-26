require 'rails_helper'

describe "POST /heritages/:heritage/oneoffs", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:heritage) { create :heritage }

  before {Aws.config[:stub_responses] = true}

  it "creates a oneoff task" do
    expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
      double(tasks: [double(task_arn: 'arn')])
    end

    params = {
      command: "rake db:migrate",
      image_tag: "v100"
    }
    post "/v1/heritages/#{heritage.name}/oneoffs", params, auth
    expect(response).to be_success
    oneoff = JSON.load(response.body)["oneoff"]
    expect(oneoff["task_arn"]).to eq "arn"
    expect(oneoff["command"]).to eq "rake db:migrate"
  end
end
