require "rails_helper"

describe ReviewApp do
  let(:group) { create :review_group }

  describe "create" do
    let(:review_app) {
      group.review_apps.new(
        subject: "subject",
        image_name: "image",
        image_tag: "tag",
        retention: 12 * 3600,
        before_deploy: "true",
        environment: [],
        services: [{
          name: "review",
          command: "true",
          service_type: "web",
        }]
      )
    }

    it "creates a heritage" do
      expect{review_app.save!}.to_not raise_error

      expect(review_app.heritage).to be_present
      expect(review_app.heritage.name).to eq "review-#{review_app.slug_digest}"
      expect(review_app.heritage.services[0].listeners[0].endpoint).to eq group.endpoint
      expect(review_app.heritage.services[0].listeners[0].rule_priority).to eq review_app.rule_priority_from_subject
      expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["type"]).to eq "host-header"
      expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["value"]).to eq review_app.domain
    end

    it "deploys the heritage" do
      expect_any_instance_of(Heritage).to receive(:deploy!)
      review_app.save!
    end

    context 'when an invalid subject is passed' do
      let(:review_app) {
        group.review_apps.new(
          subject: "subject_With_Caps_And_Underscores",
          image_name: "image",
          image_tag: "tag",
          retention: 12 * 3600,
          before_deploy: "true",
          environment: [],
          services: [{
            name: "review",
            command: "true",
            service_type: "web",
          }]
        )
      }

      it 'passes validation' do
        expect{review_app.save!}.to_not raise_error
      end

      it "converts the underscores to hyphens" do
        expect(review_app.to_param).to eq('subject-with-caps-and-underscores')
        expect(review_app.slug).to eq('review---subject-with-caps-and-underscores')
      end
    end

    context "when a service def has listeners" do
      let(:review_app) {
        group.review_apps.new(
          subject: "subject",
          image_name: "image",
          image_tag: "tag",
          retention: 12 * 3600,
          before_deploy: "true",
          environment: [],
          services: [{
            name: "review",
            command: "true",
            service_type: "web",
            listeners: [{
              health_check_path: "/healthcheck",
              health_check_interval: 300
            }]
          }])
      }

      it "preserves configurations" do
        expect{review_app.save!}.to_not raise_error

        expect(review_app.heritage).to be_present
        expect(review_app.heritage.name).to eq "review-#{review_app.slug_digest}"
        expect(review_app.heritage.services[0].listeners[0].endpoint).to eq group.endpoint
        expect(review_app.heritage.services[0].listeners[0].rule_priority).to eq review_app.rule_priority_from_subject
        expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["type"]).to eq "host-header"
        expect(review_app.heritage.services[0].listeners[0].rule_conditions[0]["value"]).to eq review_app.domain
        expect(review_app.heritage.services[0].listeners[0].health_check_interval).to eq 300
        expect(review_app.heritage.services[0].listeners[0].health_check_path).to eq "/healthcheck"
      end
    end

    context "when a service has capital letters" do
      let(:review_app) {
        group.review_apps.new(
          subject: "SUBJECT",
          image_name: "image",
          image_tag: "tag",
          retention: 12 * 3600,
          before_deploy: "true",
          environment: [],
          services: [{
            name: "review",
            command: "true",
            service_type: "web",
            listeners: [{
              health_check_path: "/healthcheck",
              health_check_interval: 300
            }]
          }])
      }

      it "preserves configurations" do
        expect(review_app).to_not be_valid
        expect(review_app.errors[:subject]).to eq(["branch name must only contain lowercase characters, numbers and hyphens, and can only start and end with a letter or a number"])
      end
    end
  end
end
