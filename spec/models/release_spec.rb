require 'rails_helper'

describe Release do
  let(:service) { build :web_service }
  let!(:heritage) { build :heritage, services: [service] }
  let(:release) { Release.new(heritage: heritage) }

  describe "before_create callback" do
    subject { release }
    before do
      release.save
    end

    its(:version) { is_expected.to eq 1 }
    its(:heritage_params) {
      is_expected.to eq({"image_name" => heritage.image_name,
                         "image_tag" => heritage.image_tag,
                         "services_attributes" => [
                           service.
                           attributes.
                           slice("id",
                                 "cpu",
                                 "memory",
                                 "command",
                                 "reverse_proxy_image",
                                 "hosts",
                                 "service_type",
                                 "force_ssl",
                                 "health_check")
                         ]})
    }
  end

  describe "#rollback" do
    before do
      release.save!
      heritage.attributes = {
        image_tag: "v111",
        services_attributes: [
          {
            id: service.id,
            command: "rails s -p 3000"
          }
        ]
      }
      heritage.save_and_deploy!
    end

    it "rollbacks to the previous version" do
      expect(heritage.image_tag).to eq "v111"
      expect(heritage.services.first.command).to eq "rails s -p 3000"

      release.rollback

      expect(heritage.image_tag).to eq "1.9.5"
      expect(heritage.services.first.command).to eq "rails s"
    end

    it "creates a rolling back release" do
      new_release = release.rollback
      heritage.reload
      expect(new_release.description).to match "Rolled back to version #{release.version}"
      expect(new_release.version).to eq(heritage.releases.count)
      expect(new_release.heritage_params).to eq release.heritage_params
    end
  end
end
