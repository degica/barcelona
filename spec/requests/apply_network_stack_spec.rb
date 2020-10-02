require "rails_helper"

describe "POST /districts/:district/apply_stack" do
  let(:district) { create :district }

  given_auth(VaultAuth) do
    let(:user) { create :user }

    context "when a user is not authorized" do
      it "returns 403" do
        allow_any_instance_of(VaultAuth).to receive(:authenticate) { user }
        allow_any_instance_of(VaultAuth).to receive(:authorize_action) { raise ExceptionHandler::Forbidden }

        api_request :post, "/v1/districts/#{district.name}/apply_stack"
        expect(response.status).to eq 403
      end
    end

    context "when a user is authorized" do
      it "updates the district" do
        allow_any_instance_of(VaultAuth).to receive(:authenticate) { user }
        allow_any_instance_of(VaultAuth).to receive(:authorize_action) { true }

        api_request :post, "/v1/districts/#{district.name}/apply_stack"
        expect(response.status).to eq 202
      end
    end
  end

  given_auth(GithubAuth) do
    context "when a user is a developer" do
      let(:user) { create :user, roles: ["developer"] }
      it "returns 403" do
        api_request :post, "/v1/districts/#{district.name}/apply_stack"
        expect(response.status).to eq 403
      end
    end

    context "when a user is an admin" do
      let(:user) { create :user, roles: ["admin"] }
      it "updates a district" do
        api_request :post, "/v1/districts/#{district.name}/apply_stack"
        expect(response.status).to eq 202
      end
    end
  end
end
