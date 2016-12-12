class AwsAccessor
  attr_accessor :district
  def initialize(district)
    @district = district
    @region = district.region
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
    if district.aws_role.present?
      access_key_id, secret_access_key = assume_role
    else
      access_key_id, secret_access_key = [district.aws_access_key_id, district.aws_secret_access_key]
    end
    Aws::Credentials.new(access_key_id, secret_access_key)
  end

  def assume_role
    sts = Aws::STS::Client.new()
    resp = sts.assume_role(
      duration_seconds: 3600,
      role_arn: district.aws_role,
      role_session_name: "barcelona-#{district.name}-session-#{Time.to_i}"
    )
    [resp.credentials.access_key_id, resp.credentials.secret_access_key]
  end
end
