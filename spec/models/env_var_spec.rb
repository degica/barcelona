require 'rails_helper'

describe EnvVar do
  let(:env_var) { EnvVar.create(key: "KEY", value: "VALUE") }

  it "saves encrypted value" do
    expect(env_var.encrypted_value).to be_present
  end

  it "decrypts encrypted value" do
    expect(EnvVar.find(env_var.id).key).to eq "KEY"
    expect(EnvVar.find(env_var.id).value).to eq "VALUE"
    expect(EnvVar.find(env_var.id).value).to be_a String
  end
end
