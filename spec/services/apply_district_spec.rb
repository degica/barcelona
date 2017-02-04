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
    let(:iam_stub) { double }

    before do
      ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'] = "/v2/ecs/"
      expect(Net::HTTP).to receive(:get_response) do
        double(
          code: "200",
          body: {"RoleArn" => "role_arn"}.to_json
        )
      end

      allow(Aws::IAM::Client).to receive(:new) { iam_stub }
    end

    after do
      ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'] = nil
    end

    describe "#create!" do
      it "creates AWS resources" do
        expect(iam_stub).to receive(:get_role) {
          raise Aws::IAM::Errors::NoSuchEntity.new(nil, nil)
        }

        expect(iam_stub).to receive(:create_role) {
          double(
            role: double(arn: 'role-arn')
          )
        }

        expect(iam_stub).to receive(:put_role_policy)

        described_class.new(district).create!("access_key_id", "secret_access_key")

        expect(district.aws_role).to eq "role-arn"
        expect(district.aws_access_key_id).to be_nil
        expect(district.aws_secret_access_key).to be_nil
      end

      context "when district role exists" do
        it "do not create role" do
          expect(iam_stub).to receive(:get_role) {
            double(
              role: double(arn: 'role-arn')
            )
          }

          expect(iam_stub).to_not receive(:create_role)
          expect(iam_stub).to_not receive(:put_role_policy)

          described_class.new(district).create!("access_key_id", "secret_access_key")

          expect(district.aws_role).to eq "role-arn"
          expect(district.aws_access_key_id).to be_nil
          expect(district.aws_secret_access_key).to be_nil
        end
      end
    end
  end
end
