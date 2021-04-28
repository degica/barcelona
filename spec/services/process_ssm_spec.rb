require "rails_helper"

describe ProcessSsm do
  let(:district) { build :district, aws_access_key_id: 'test', aws_secret_access_key: 'test' }

  let(:name) {"PSParameterName"}

  describe "#get_parameter" do
    it "get ssm parameters" do
      response = described_class.new(district, name).get_parameter
      expect(response.parameter.name).to eq name
      expect(response.parameter.value).to eq "PSParameterValue"
    end

    it "throw an error if credential is not set" do
      district.aws_access_key_id = ""
      expect { described_class.new(district, name).get_parameter }
          .to raise_error Aws::Errors::MissingCredentialsError
    end

    it "throw an error if key is not set" do
      district.aws.ssm.stub_responses(:get_parameter, Aws::SSM::Errors::ParameterNotFound.new(nil, nil, nil))
      expect { described_class.new(district, name).get_parameter }
          .to raise_error Aws::SSM::Errors::ParameterNotFound
    end
  end

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
