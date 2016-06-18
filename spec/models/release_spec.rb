require 'rails_helper'

describe Release do
  let(:service) { build :web_service }
  let!(:app) { build :app, services: [service] }
  let(:release) { Release.new(app: app) }

  describe "before_create callback" do
    subject { release }
    before do
      release.save
    end

    its(:version) { is_expected.to eq 1 }
    its(:app_params) {
      is_expected.to eq({"image_name" => app.image_name,
                         "image_tag" => app.image_tag,
                         "services_attributes" => [
                           service.
                           attributes.
                           with_indifferent_access.
                           slice("id",
                                 "cpu",
                                 "memory",
                                 "command",
                                 "reverse_proxy_image",
                                 "hosts",
                                 "service_type",
                                 "force_ssl",
                                 "health_check")]})
    }
  end

  describe "#rollback" do
    before do
      release.save!
      app.attributes = {
        image_tag: "v111",
        services_attributes: [
          {
            id: service.id,
            command: "rails s"
          }
        ]
      }
      app.save_and_deploy!
    end

    it "rollbacks to the previous version" do
      expect(app.image_tag).to eq "v111"
      expect(app.services.first.command).to eq "rails s"

      release.rollback

      expect(app.image_tag).to eq "1.9.5"
      expect(app.services.first.command).to eq nil
    end

    it "creates a rolling back release" do
      new_release = release.rollback
      app.reload
      expect(new_release.description).to match "Rolled back to version #{release.version}"
      expect(new_release.version).to eq(app.releases.count)
      expect(new_release.app_params).to eq release.app_params
    end
  end
end
