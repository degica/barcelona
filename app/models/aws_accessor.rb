class AwsAccessor
  def initialize(access_key_id, secret_access_key, region)
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
    @region = region
  end

  def ecs
    @ecs ||= Aws::ECS::Client.new(client_config)
  end

  def s3
    @s3 ||= Aws::S3::Client.new(client_config)
  end

  def ec2
    @ec2 ||= Aws::EC2::Client.new(client_config)
  end

  def elb
    @elb ||= Aws::ElasticLoadBalancing::Client.new(client_config)
  end

  def route53
    @route53 ||= Aws::Route53::Client.new(client_config)
  end

  def cloudformation
    @cloudformation ||= Aws::CloudFormation::Client.new(client_config)
  end

  private

  def client_config
    {region: @region, credentials: credentials}
  end

  def credentials
    Aws::Credentials.new(@access_key_id, @secret_access_key)
  end
end
