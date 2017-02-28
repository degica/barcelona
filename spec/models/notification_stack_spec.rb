require 'rails_helper'

describe NotificationStack do
  let(:district) { create :district }

  it "generates notification stack" do
    district.notifications.create(
        target: "slack",
        endpoint: "https://hooks.slack.com/services/webhook/endpoint"
    )
    stack = described_class.new(district)
    generated = JSON.load(stack.target!)
    expect(generated["Resources"]["NotificationRole"]).to be_present
    expect(generated["Resources"]["SlackSubscription0"]).to be_present
    expect(generated["Resources"]["NotificationPermission0"]).to be_present
    expect(generated["Resources"]["SlackNotification0"]).to be_present
  end
end
