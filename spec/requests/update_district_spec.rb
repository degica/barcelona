require 'rails_helper'

describe "PATCH /districts/:district", type: :request do
  let(:district) { create :district }

  context "when a user is a developer" do
    let(:user) { create :user, roles: ["developer"] }
    it "returns 403" do
      api_request :patch, "/v1/districts/#{district.name}"
      expect(response.status).to eq 403
    end
  end

  context "when a user is an admin" do
    let(:user) { create :user, roles: ["admin"] }
    it "udpates a district" do
      dockercfg = {
        "auths" => {
          "quay.io" => {
            "auth" => "abcdefgh"
          }
        }
      }

      params = {
        cluster_size: 10,
        auto_scaling_instance_types: ["m5.large", "m4.large"],
        dockercfg: dockercfg
      }

      api_request :patch, "/v1/districts/#{district.name}", params
      expect(response.status).to eq 200

      district.reload

      expect(district.cluster_size).to eq 10
      expect(district.auto_scaling_instance_types).to eq ["m5.large", "m4.large"]
      expect(district.dockercfg).to eq dockercfg
    end

    context "when running in ECS environment" do
      mock_ecs_task_environment(role_arn: 'role-arn')

      it "udpates a district aws role" do
        params = {
          aws_access_key_id: 'access_key_id',
          aws_secret_access_key: 'secret_access_key',
        }

        expect(district.aws_access_key_id).to be_present
        expect(district.aws_secret_access_key).to be_present

        api_request :patch, "/v1/districts/#{district.name}", params
        district.reload

        expect(response.status).to eq 200
        expect(district.aws_access_key_id).to be_nil
        expect(district.aws_secret_access_key).to be_nil
        expect(district.aws_role).to eq "role-arn"
      end
    end
  end
end
