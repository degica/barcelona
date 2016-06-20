require 'rails_helper'

describe App do
  let(:app) { build :app }

  describe "#save_and_deploy!" do
    it "enqueues deploy job" do
      expect(DeployRunnerJob).to receive(:perform_later).with(app,
                                                              without_before_deploy: false,
                                                              description: "deploy")
      release = app.save_and_deploy!(description: "deploy")
      expect(release.description).to eq "deploy"
    end
  end

  describe "#describe_services" do
    it { expect(app.describe_services).to eq [] }
  end

  describe "#image_path" do
    context "when image_name is blank" do
      let(:app) { build :app, image_name: nil, image_tag: nil }
      it { expect(app.image_path).to be_nil }
    end

    context "when image_name is present" do
      let(:app) { build :app, image_name: 'nginx', image_tag: nil }
      it { expect(app.image_path).to eq "nginx:latest" }
    end

    context "when image_tag is present" do
      let(:app) { build :app, image_name: 'nginx', image_tag: "master" }
      it { expect(app.image_path).to eq "nginx:master" }
    end
  end
end
