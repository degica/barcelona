require 'rails_helper'

describe EnvVar do
  let(:env_var) { create :env_var }

  it "saves encrypted value" do
    expect(env_var.encrypted_value).to be_present
  end

  it "decrypts encrypted value" do
    expect(EnvVar.find(env_var.id).key).to eq "KEY"
    expect(EnvVar.find(env_var.id).value).to eq "VALUE"
    expect(EnvVar.find(env_var.id).value).to be_a String
  end

  context "if secret is true" do
    let(:env_var) { build :env_var, key: "KEY", value: "VALUE", secret: true }

    it "doesn't save value in DB" do
      expect(env_var.district.aws.s3).to receive(:put_object).with(
                                           bucket: env_var.district.s3_bucket_name,
                                           key: env_var.s3_path,
                                           body: "VALUE",
                                           server_side_encryption: "aws:kms")
      env_var.save!
      expect(env_var.encrypted_value).to be_nil
      expect(env_var.value).to be_blank
    end
  end

  context "when env_var is updated to be secret" do
    before do
      env_var.update!(secret: true)
    end

    its(:value) { is_expected.to be_blank }
  end
end
