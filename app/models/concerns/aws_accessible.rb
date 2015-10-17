module AwsAccessible
  extend ActiveSupport::Concern

  def ecs
    Aws::ECS::Client.new
  end

  def s3
    Aws::S3::Client.new
  end

  def ec2
    Aws::EC2::Client.new
  end

  def elb
    Aws::ElasticLoadBalancing::Client.new
  end

  def route53
    Aws::Route53::Client.new
  end
end
