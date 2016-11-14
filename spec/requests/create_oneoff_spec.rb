require 'rails_helper'

describe "POST /heritages/:heritage/oneoffs", type: :request do
  let(:user) { create :user }
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

  it "creates a oneoff task" do
    expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
      run_task_response_mock
    end

    params = {
      command: "rake db:migrate"
    }
    api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
    expect(response).to be_success
    oneoff = JSON.load(response.body)["oneoff"]
    expect(oneoff["task_arn"]).to eq "arn"
    expect(oneoff["container_instance_arn"]).to eq "container_instance_arn"
    expect(oneoff["exit_code"]).to eq nil
    expect(oneoff["command"]).to eq "rake db:migrate"
  end

  context "when interactive oneoff is requested" do
    let(:user) { create :user, public_key: public_key }
    let(:ca_key_pair) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) do
      key = OpenSSL::PKey::RSA.new(1024).public_key
      "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
    end

    before do
      allow_any_instance_of(District).to receive(:get_ca_key) { ca_key_pair.to_pem }
    end

    it "creates a interactive oneoff task" do
      expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
        run_task_response_mock
      end

      params = {
        interactive: true,
        command: "rake db:migrate"
      }

      api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
      expect(response).to be_success
      resp = JSON.load(response.body)
      expect(resp["oneoff"]["task_arn"]).to eq "arn"
      expect(resp["oneoff"]["container_instance_arn"]).to eq "container_instance_arn"
      expect(resp["oneoff"]["exit_code"]).to eq nil
      expect(resp["oneoff"]["command"]).to eq "rake db:migrate"
      expect(resp["oneoff"]["interactive_run_command"]).to be_a String
      expect(resp["certificate"]).to be_a String
    end
  end
end
