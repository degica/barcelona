module Support
  module MockEcsEnv
    def mock_ecs_task_environment(role_arn: 'role-arn', preexist: false)
      let(:iam_stub) { double }

      before do
        relative_uri = ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'] = "/v2/ecs/"
        expect(Net::HTTP).to receive(:get_response).with(URI("http://169.254.170.2#{relative_uri}")) do
          double(
            code: "200",
            body: {"RoleArn" => "role_arn"}.to_json
          )
        end

        allow(Aws::IAM::Client).to receive(:new) { iam_stub }
        if preexist
          expect(iam_stub).to receive(:get_role) {
            double(
              role: double(arn: role_arn)
            )
          }
          expect(iam_stub).to_not receive(:create_role)
          expect(iam_stub).to_not receive(:put_role_policy)
        else
          allow(iam_stub).to receive(:get_role) {
            raise Aws::IAM::Errors::NoSuchEntity.new(nil, nil)
          }

          allow(iam_stub).to receive(:create_role) {
            double(
              role: double(arn: role_arn)
            )
          }

          allow(iam_stub).to receive(:put_role_policy)
        end
      end

      after do
        ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'] = nil
      end
    end
  end
end

RSpec.configure do |c|
  c.extend Support::MockEcsEnv
end
