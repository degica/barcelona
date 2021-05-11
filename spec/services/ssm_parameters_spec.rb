require "rails_helper"

describe SsmParameters do
  let(:district) { build :district, name: 'districtname', aws_access_key_id: 'test', aws_secret_access_key: 'test' }

  describe "#ssm_path" do
    it "returns expected ssm_path" do
      expect(described_class.new(district, 'app/paramname').ssm_path).to eq "/barcelona/districtname/app/paramname"
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
