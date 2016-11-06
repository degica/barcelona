require 'rails_helper'

describe Heritage do
  let(:heritage) { build :heritage }

  describe "#save_and_deploy!" do
    it "enqueues deploy job" do
      expect(DeployRunnerJob).to receive(:perform_later).with(heritage,
                                                              without_before_deploy: false,
                                                              description: "deploy")
      release = heritage.save_and_deploy!(description: "deploy")
      expect(release.description).to eq "deploy"
    end
  end

  describe "#describe_services" do
    it { expect(heritage.describe_services).to eq [] }
  end

  describe "#image_path" do
    context "when image_name is blank" do
      let(:heritage) { build :heritage, image_name: nil, image_tag: nil }
      it { expect(heritage.image_path).to be_nil }
    end

    context "when image_name is present" do
      let(:heritage) { build :heritage, image_name: 'nginx', image_tag: nil }
      it { expect(heritage.image_path).to eq "nginx:latest" }
    end

    context "when image_tag is present" do
      let(:heritage) { build :heritage, image_name: 'nginx', image_tag: "master" }
      it { expect(heritage.image_path).to eq "nginx:master" }
    end
  end
end

describe Heritage::Stack do
  let(:heritage) { build :heritage }
  let(:stack) { described_class.new(heritage) }

  describe "#target!" do
    it "generates a correct stack template" do
      generated = JSON.load stack.target!
      expected = {
        "LogGroup" => {
          "Type" => "AWS::Logs::LogGroup",
          "Properties" => {
            "LogGroupName" => "Barcelona/#{heritage.district.name}/#{heritage.name}",
            "RetentionInDays" => 365
          }
        },
        "TaskRole" => {
          "Type" => "AWS::IAM::Role",
          "Properties" => {
            "AssumeRolePolicyDocument" => {
              "Version" => "2012-10-17",
              "Statement" => [
                {
                  "Effect"=>"Allow",
                  "Principal" => {
                    "Service" => [
                      "ecs-tasks.amazonaws.com"
                    ]
                  },
                  "Action" => [
                    "sts:AssumeRole"
                  ]
                }
              ]
            },
            "Path" => "/",
            "Policies" => [
              {
                "PolicyName" => "barcelona-ecs-task-role-#{heritage.name}",
                "PolicyDocument" => {
                  "Version" => "2012-10-17",
                  "Statement" => [
                    {
                      "Effect" => "Allow",
                      "Action" => [
                        "s3:Get*",
                        "s3:List*",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                      ],
                      "Resource"=>["*"]
                    }
                  ]
                }
              }
            ]
          }
        }
      }
      expect(generated["Resources"]).to eq expected
    end

    context "when a heritage has scheduled tasks" do
      let(:heritage) { build :heritage,
                             scheduled_tasks: [{schedule: 'rate(1 minute)',
                                                command: 'echo hello'}] }
      it "generates a correct stack template" do
        generated = JSON.load stack.target!
        expect(generated["Resources"]["ScheduledEvent0"]).to be_present
        expect(generated["Resources"]["PermissionForScheduledEvent0"]).to be_present
        expect(generated["Resources"]["ScheduleHandler"]).to be_present
        expect(generated["Resources"]["ScheduleHandlerRole"]).to be_present
      end
    end
  end
end
