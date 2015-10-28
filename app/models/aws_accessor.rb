class AwsAccessor
  def initialize(access_key_id, secret_access_key)
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
  end

  def ecs
    @ecs ||= Aws::ECS::Client.new(credentials: credentials)
  end

  def s3
    @s3 ||= Aws::S3::Client.new(credentials: credentials)
  end

  def ec2
    @ec2 ||= Aws::EC2::Client.new(credentials: credentials)
  end

  def elb
    @elb ||= Aws::ElasticLoadBalancing::Client.new(credentials: credentials)
  end

  def route53
    @route53 ||= Aws::Route53::Client.new(credentials: credentials)
  end

  private

  def credentials
    Aws::Credentials.new(@access_key_id, @secret_access_key)
  end
end
