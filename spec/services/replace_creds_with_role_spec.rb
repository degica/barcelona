require 'rails_helper'

describe ReplaceCredsWithRole, type: :model do
  mock_ecs_task_environment(role_arn: "role-arn")

  let(:district) { create :district }

  it "replaces AWS credentials with role" do
    expect(district.aws_access_key_id).to be_present
    expect(district.aws_secret_access_key).to be_present

    described_class.new(district).run!

    expect(district.aws_access_key_id).to be_nil
    expect(district.aws_secret_access_key).to be_nil
    expect(district.aws_role).to eq "role-arn"
  end
end
