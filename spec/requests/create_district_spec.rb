require 'rails_helper'

describe "POST /districts", type: :request do
  let(:params) do
    {
      name: "district",
      region: "ap-northeast-1",
      aws_access_key_id: "awsaccessskeyid",
      aws_secret_access_key: "secret key",
    }
  end

  given_auth(GithubAuth) do
    context "when a user is a developer" do
      let(:user) { create :user, roles: ["developer"] }
      it "returns 403" do
        api_request :post, "/v1/districts", params
        expect(response.status).to eq 403
      end
    end

    context "when a user is an admin" do
      let(:user) { create :user, roles: ["admin"] }
      it "creates a district" do
        api_request :post, "/v1/districts", params
        expect(response.status).to eq 201

        body = JSON.load(response.body)
        expect(body["district"]["name"]).to eq "district"
        expect(body["district"]["region"]).to eq "ap-northeast-1"
        expect(body["district"]["cidr_block"]).to match %r{10\.[0-9]+\.0.0\/16}
        expect(body["district"]["stack_name"]).to eq "barcelona-district"
        expect(body["district"]["s3_bucket_name"]).to match %r{barcelona-district-[0-9]+}
        expect(body["district"]["nat_type"]).to eq "instance"
        expect(body["district"]["cluster_size"]).to eq 1
        expect(body["district"]["cluster_backend"]).to eq "autoscaling"
        expect(body["district"]["cluster_instance_type"]).to eq "t3.small"
      end

      context "when running in ECS environment" do
        mock_ecs_task_environment(role_arn: 'role-arn')

        it "creates a district with district role" do
          api_request :post, "/v1/districts", params
          expect(response.status).to eq 201

          body = JSON.load(response.body)
          expect(body["district"]["aws_access_key_id"]).to be_nil
          expect(body["district"]["aws_role"]).to eq "role-arn"
        end
      end
    end
  end
end
