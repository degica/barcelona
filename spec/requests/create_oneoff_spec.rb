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
      ],
      failures: []
    )
  }

  it "creates a oneoff task" do
    expect_any_instance_of(Aws::ECS::Client).to receive(:run_task) do
      run_task_response_mock
    end

    params = {
      command: "rake db:migrate",
      memory: 1024
    }
    api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
    expect(response).to be_successful
    oneoff = JSON.load(response.body)["oneoff"]
    expect(oneoff["task_arn"]).to eq "arn"
    expect(oneoff["container_instance_arn"]).to eq "container_instance_arn"
    expect(oneoff["exit_code"]).to eq nil
    expect(oneoff["command"]).to eq "rake db:migrate"
    expect(oneoff["memory"]).to eq 1024
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
      allow_any_instance_of(Aws::ECS::Client).to receive(:run_task) { run_task_response_mock }
    end

    it "creates a interactive oneoff task" do
      params = {
        interactive: true,
        command: "rake db:migrate"
      }

      api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
      expect(response).to be_successful
      resp = JSON.load(response.body)
      expect(resp["oneoff"]["task_arn"]).to eq "arn"
      expect(resp["oneoff"]["container_instance_arn"]).to eq "container_instance_arn"
      expect(resp["oneoff"]["exit_code"]).to eq nil
      expect(resp["oneoff"]["command"]).to eq "rake db:migrate"
      expect(resp["oneoff"]["interactive_run_command"]).to be_a String
      expect(resp["certificate"]).to be_a String
    end

    context ':env_vars param' do
      it 'creates a task if the env_vars param is a proper hash' do
        params = {
          interactive: true,
          command: "rake db:migrate",
          env_vars: {
            "FOO" => "bar"
          }
        }

        api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
        expect(response).to be_successful
      end

      it 'throws a 400 if the env_vars param is not a hash' do
        params = {
          interactive: true,
          command: "rake db:migrate",
          env_vars: "invalidness"
        }

        api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
        expect(response).to be_a_bad_request
      end

      it 'throws a 400 if the env_vars param is a hash that contains hashes' do
        params = {
          interactive: true,
          command: "rake db:migrate",
          env_vars: {
            "FOO": {
              "bar" => "baz"
            }
          }
        }

        api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
        expect(response).to be_a_bad_request
      end

      it 'throws a 400 if the env_var param is weird' do
        params = {
          interactive: true,
          command: "rake db:migrate",
          env_vars: 1231
        }

        api_request :post, "/v1/heritages/#{heritage.name}/oneoffs", params
        expect(response).to be_a_bad_request
      end
    end
  end
end
