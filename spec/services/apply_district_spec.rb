require "rails_helper"

describe ApplyDistrict do
  let(:district) { build :district }

  describe "#create!" do
    it "creates AWS resources" do
      described_class.new(district).create!("access_key_id", "secret_access_key")
    end
  end

  describe "#update!" do
    it "updates AWS resources with key" do
      district.save!
      described_class.new(district).update!("new_access_key_id", "new_secret_access_key")
      expect(district.aws_access_key_id).to eq "new_access_key_id"
      expect(district.aws_secret_access_key).to eq "new_secret_access_key"
    end

    it "updates AWS resources without key" do
      district.save!
      described_class.new(district).update!
    end
  end

  describe "#destroy" do
    it "deletes AWS resources" do
      district.save!
      described_class.new(district).destroy!
    end
  end

  context "When running as ECS task" do

    describe "#create!" do
      context "when district role does not exist" do
        mock_ecs_task_environment

        it "creates AWS resources" do
          described_class.new(district).create!("access_key_id", "secret_access_key")

          expect(district.aws_role).to eq "role-arn"
          expect(district.aws_access_key_id).to be_nil
          expect(district.aws_secret_access_key).to be_nil
        end
      end

      context "when district role exists" do
        mock_ecs_task_environment(role_arn: 'role-arn', preexist: true)

        it "do not create role" do
          described_class.new(district).create!("access_key_id", "secret_access_key")

          expect(district.aws_role).to eq "role-arn"
          expect(district.aws_access_key_id).to be_nil
          expect(district.aws_secret_access_key).to be_nil
        end
      end
    end
  end
end
