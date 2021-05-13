require "rails_helper"

describe SsmParameters do
  let(:district) { build :district, name: 'district_name', aws_access_key_id: 'test', aws_secret_access_key: 'test' }
  let(:name) { district.name }

  describe "#ssm_path" do
    it "returns expected ssm_path" do
      expect(described_class.new(district, 'app/param_name').ssm_path).to eq "/barcelona/district_name/app/param_name"
    end
  end

  describe "#put_parameter" do
    let(:parameter_value) { "test123"}

    it "put ssm parameters" do
      type = "SecureString"
      response = described_class.new(district, name).put_parameter(parameter_value, type)
      expect(response.version).to eq 0
    end

    it "put unexpected type parameters" do
      type = "hoge"

      expect { described_class.new(district, name).put_parameter(parameter_value, type) }.
        to raise_error ExceptionHandler::InternalServerError
    end
  end

  describe "#delete_parameter" do
    it "delete ssm parameter" do
      response = described_class.new(district, name).delete_parameter
      expect(response.deleted_parameters).to eq []
      expect(response.invalid_parameters).to eq []
    end
  end
end
