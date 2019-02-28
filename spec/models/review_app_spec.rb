require "rails_helper"

describe ReviewApp do
  let(:group) { create :review_group }

  describe "create" do
    let(:review_app) {
      group.review_apps.new(
        subject: "subject",
        image_name: "image",
        image_tag: "tag",
        retention_hours: 12,
        before_deploy: "true",
        environment: [],
        service_params: {
          command: "true",
          service_type: "web",
        }
      )
    }

    it "creates a heritage" do
      expect{review_app.save!}.to_not raise_error

      expect(review_app.heritage).to be_present
      expect(review_app.heritage.name).to eq "review-#{review_app.unique_slug}"
      expect(review_app.heritage.services[0].listeners[0].endpoint).to eq group.endpoint
      expect(review_app.heritage.services[0].listeners[0].rule_priority).to eq review_app.rule_priority_from_subject
      expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["type"]).to eq "host-header"
      expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["value"]).to eq review_app.domain
    end

    it "deploys the heritage" do
      expect_any_instance_of(Heritage).to receive(:deploy!)
      review_app.save!
    end
  end
end
