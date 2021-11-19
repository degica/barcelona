class EcrService
  def initialize(heritage)
    @heritage = heritage
  end

  def validate_image!
    ecr.describe_images({
                          image_ids: [
                            {
                              image_tag: @heritage.tag
                            }
                          ],
                          repository_name: repository_name
                        })
  rescue => e
    raise ExceptionHandler::BadRequest.new("Validation failed in ECR: error #{e} image_path: #{@heritage.image_path}")
  end

  private

  def ecr
    @ecr ||= @heritage.district.aws.ecr(@heritage.image_name)
  end

  # The string after the last / will be matched.
  # For example, when the Image name is public.ecr.aws/degica/barcelona,
  # it will return barcelona.
  def repository_name
    @heritage.image_name[%r{/([^/]*?)$}, 1]
  end
end
