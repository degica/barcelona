require 'rails_helper'

describe EcrService do
  let(:district) { build :district, name: 'district_name', aws_access_key_id: 'test', aws_secret_access_key: 'test', heritages: [heritage] }
  let(:heritage) { build :heritage, image_name: image_name, image_tag: image_tag }
  let(:image_name) { "public.ecr.aws/degica/barcelona" }
  let(:image_tag) { "latest" }

  describe "#validate_image!" do
    context 'when a public image' do
      it "when image exists in ecr, do not throw an error" do
        expect_any_instance_of(Aws::ECRPublic::Client).to receive(:describe_images).
          with(image_ids: [
                 {
                   image_tag: image_tag
                 }

               ],
               repository_name: "barcelona").and_call_original
        expect { described_class.new.validate_image!(heritage) }.not_to raise_error
      end

      it "when image does not exist in ECR, throw an Bad Request Error" do
        ecr_public = Aws::ECRPublic::Client.new(stub_responses: true)
        ecr_public.stub_responses(:describe_images, Aws::ECRPublic::Errors::RepositoryNotFoundException.new(nil, nil))
        allow_any_instance_of(EcrService).to receive(:ecr_public).and_return(ecr_public)

        expect { described_class.new.validate_image!(heritage) }.to raise_error(ExceptionHandler::BadRequest)
      end

      it "when image tag does not exist in ECR, throw an Bad Request Error" do
        ecr_public = Aws::ECRPublic::Client.new(stub_responses: true)
        ecr_public.stub_responses(:describe_images, Aws::ECRPublic::Errors::ImageNotFoundException.new(nil, nil))
        allow_any_instance_of(EcrService).to receive(:ecr_public).and_return(ecr_public)

        expect { described_class.new.validate_image!(heritage) }.to raise_error(ExceptionHandler::BadRequest)
      end
    end

    context 'when a private image' do
      let(:image_name) { "111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/barcelona" }
      it "when image exists in ecr, do not throw an error" do
        expect_any_instance_of(Aws::ECR::Client).to receive(:describe_images).
          with(image_ids: [
                 {
                   image_tag: image_tag
                 }

               ],
               repository_name: "barcelona").and_call_original
        expect { described_class.new.validate_image!(heritage) }.not_to raise_error
      end

      it "when image does not exist in ECR, throw an Bad Request Error" do
        ecr_private = Aws::ECR::Client.new(stub_responses: true)
        ecr_private.stub_responses(:describe_images, Aws::ECR::Errors::RepositoryNotFoundException.new(nil, nil))
        allow_any_instance_of(EcrService).to receive(:ecr_private).and_return(ecr_private)

        expect { described_class.new.validate_image!(heritage) }.to raise_error(ExceptionHandler::BadRequest)
      end

      it "when image tag does not exist in ECR, throw an Bad Request Error" do
        ecr_private = Aws::ECR::Client.new(stub_responses: true)
        ecr_private.stub_responses(:describe_images, Aws::ECR::Errors::ImageNotFoundException.new(nil, nil))
        allow_any_instance_of(EcrService).to receive(:ecr_private).and_return(ecr_private)

        expect { described_class.new.validate_image!(heritage) }.to raise_error(ExceptionHandler::BadRequest)
      end
    end
  end
end
