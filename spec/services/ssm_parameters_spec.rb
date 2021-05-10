require "rails_helper"

describe SsmParameters do
  let(:district) { build :district, aws_access_key_id: 'test', aws_secret_access_key: 'test' }

  let(:name) {"PSParameterName"}

  describe "#ssm_path" do
    it "returns expected ssm_path" do
      expect(described_class.new(district, name).ssm_path).to eq "/barcelona/#{district.name}/#{name}"
    end
  end

  describe "#put_parameter" do
    let(:parameter_value) { "test123"}

    it "put ssm parameteRs" do
      type = "SecureString"
      response = described_class.new(district, name).put_parameter(parameter_value, type)
      expect(response.version).to eq 0
    end

    it "put unexpected type parameters" do
      type = "hoge"

      expect { described_class.new(district, name).put_parameter(parameter_value, type) }
      .to raise_error ExceptionHandler::InternalServerError
    end
  end
end
