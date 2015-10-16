require 'rails_helper'

describe Heritage, :vcr do
  let(:heritage) { build :heritage }

  describe "create" do
    it "enqueues deploy job" do
      expect(DeployRunnerJob).to receive(:perform_later).with(heritage)
      heritage.save!
    end
  end
end
