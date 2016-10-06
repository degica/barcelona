require 'rails_helper'

describe "POST /heritages/:heritage/oneoffs", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:heritage) { create :heritage }
  let(:run_task_response_mock) {
    double(
      tasks: [
        double(
          task_arn: "arn",
          container_instance_arn: "container_instance_arn",
          last_status: "PENDING",
          containers: [
            double(
              name: "#{heritage.name}-oneoff",
              container_arn: "container-arn",
              exit_code: nil,
              reason: nil
            )
          ]
        )
      ]
    )
  }

  before {Aws.config[:stub_responses] = true}

  it "creates a oneoff task" do
    expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
      run_task_response_mock
    end

    params = {
      command: "rake db:migrate"
    }
    post "/v1/heritages/#{heritage.name}/oneoffs", params, auth
    expect(response).to be_success
    oneoff = JSON.load(response.body)["oneoff"]
    expect(oneoff["task_arn"]).to eq "arn"
    expect(oneoff["container_instance_arn"]).to eq "container_instance_arn"
    expect(oneoff["exit_code"]).to eq nil
    expect(oneoff["command"]).to eq "rake db:migrate"
  end
end
