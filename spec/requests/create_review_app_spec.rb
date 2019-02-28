require 'rails_helper'

describe "POST /v1/:review_group/apps", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:endpoint) { create :endpoint, district: district }
  let(:review_group) { create(:review_group) }
  let(:params) do
    {
      group: review_group.name,
      subject: "branch-name",
      image_name: "nginx",
      image_tag: "v2",
      before_deploy: "before_deploy_command",
      environment: [
        {name: "ENV", value: "value"},
        {name: "SECRET", value_from: "/secret/env"}
      ],
      service: {
        service_type: "web",
        cpu: 128,
        memory: 256,
        command: "nginx",
      }
    }
  end

  it "creates a heritage" do
    allow(DeployRunnerJob).to receive(:perform_later)
    api_request(:post, "/v1/review_groups/#{review_group.name}/apps", params)
    expect(response.status).to eq 200
    review_app = JSON.load(response.body)["review_app"]
    expect(review_app["domain"]).to eq "branch-name.review.basedomain.com"
    expect(review_app["subject"]).to eq "branch-name"
    expect(review_app["heritage"]["image_name"]).to eq params[:image_name]
    expect(review_app["heritage"]["image_tag"]).to eq params[:image_tag]
    expect(review_app["heritage"]["before_deploy"]).to eq "before_deploy_command"
    expect(review_app["heritage"]["environment"].count).to eq 2
    expect(review_app["heritage"]["environment"][0]["name"]).to eq "ENV"
    expect(review_app["heritage"]["environment"][0]["value"]).to eq "value"
    expect(review_app["heritage"]["environment"][1]["name"]).to eq "SECRET"
    expect(review_app["heritage"]["environment"][1]["value_from"]).to eq "/secret/env"
    expect(review_app["heritage"]["token"]).to be_a String
    expect(review_app["heritage"]["scheduled_tasks"]).to be_empty
  end

  context "trigger API" do
    it "creates a heritage" do
      allow(DeployRunnerJob).to receive(:perform_later)
      api_request(:post, "/v1/review_groups/#{review_group.name}/apps/trigger/#{review_group.token}", params, {"X-Barcelona-Token" => nil})
      expect(response.status).to eq 200
    end

    context "with wrong token" do
      it "creates a heritage" do
        allow(DeployRunnerJob).to receive(:perform_later)
        api_request(:post, "/v1/review_groups/#{review_group.name}/apps/trigger/wrong-token", params, {"X-Barcelona-Token" => nil})
        expect(response.status).to eq 404
      end
    end
  end

  context "when the API is called twice" do
    it "updates an existing heritage" do
      allow(DeployRunnerJob).to receive(:perform_later)

      api_request(:post, "/v1/review_groups/#{review_group.name}/apps", params)
      expect(response.status).to eq 200

      second_params = params.merge(
        image_tag: "next_version",
        environment: [
          {name: "ENV", value: "value1"},
          {name: "ENV2", value: "value2"},
          {name: "SECRET", value_from: "/secret/env"}
        ],
      )

      api_request(:post, "/v1/review_groups/#{review_group.name}/apps", second_params)
      expect(response.status).to eq 200

      expect(ReviewApp.count).to eq 1
      expect(Heritage.count).to eq 1
      review_app = JSON.load(response.body)["review_app"]
      expect(review_app["domain"]).to eq "branch-name.review.basedomain.com"
      expect(review_app["subject"]).to eq "branch-name"
      expect(review_app["heritage"]["image_name"]).to eq params[:image_name]
      expect(review_app["heritage"]["image_tag"]).to eq "next_version"
      expect(review_app["heritage"]["before_deploy"]).to eq "before_deploy_command"
      expect(review_app["heritage"]["environment"].count).to eq 3
      expect(review_app["heritage"]["environment"][0]["name"]).to eq "ENV"
      expect(review_app["heritage"]["environment"][0]["value"]).to eq "value1"
      expect(review_app["heritage"]["environment"][1]["name"]).to eq "ENV2"
      expect(review_app["heritage"]["environment"][1]["value"]).to eq "value2"
      expect(review_app["heritage"]["environment"][2]["name"]).to eq "SECRET"
      expect(review_app["heritage"]["environment"][2]["value_from"]).to eq "/secret/env"
      expect(review_app["heritage"]["token"]).to be_a String
      expect(review_app["heritage"]["scheduled_tasks"]).to be_empty
    end
  end
end
