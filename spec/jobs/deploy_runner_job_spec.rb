require 'rails_helper'

describe DeployRunnerJob, type: :job do
  it 'creates an event if another deploy is in progress' do
    job = DeployRunnerJob.new

    district_object = create :district
    heritage = create :heritage, district: district_object
    allow(job).to receive(:other_deploy_in_progress?) { true }

    event_object = double("Event")
    expect(event_object).to receive(:notify)

    expect(Event).to receive(:new).with(district_object) { event_object }

    job.perform(heritage, without_before_deploy: true, description: "meow")
  end
end
