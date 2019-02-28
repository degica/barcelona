class Endpoint < ActiveRecord::Base
  class Builder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::ElasticLoadBalancingV2::LoadBalancer", "LB") do |j|
        j.Name endpoint.name
        j.Scheme lb_scheme
        j.SecurityGroups [lb_security_group]
        j.Subnets lb_subnets
        j.LoadBalancerAttributes [
          {
            "Key" => "access_logs.s3.enabled",
            "Value" => true
          },
          {
            "Key" => "access_logs.s3.bucket",
            "Value" => endpoint.district.s3_bucket_name
          },
          {
            "Key" => "access_logs.s3.prefix",
            "Value" => "elb_logs/endpoint/#{endpoint.name}"
          }
        ]
        j.Tags [
          tag("barcelona", district.name)
        ]
      end

      add_resource("AWS::ElasticLoadBalancingV2::Listener", "LBListenerHTTP") do |j|
        j.DefaultActions [
          {"TargetGroupArn" => ref("DefaultTargetGroup"), "Type" => "forward"}
        ]
        j.LoadBalancerArn ref("LB")
        j.Port 80
        j.Protocol "HTTP"
      end

      if endpoint.certificate_id.present?
        add_resource("AWS::ElasticLoadBalancingV2::Listener", "LBListenerHTTPS") do |j|
          j.Certificates [{"CertificateArn" => endpoint.certificate_id}]
          j.DefaultActions [
            {"TargetGroupArn" => ref("DefaultTargetGroup"), "Type" => "forward"}
          ]
          j.LoadBalancerArn ref("LB")
          j.Port 443
          j.Protocol "HTTPS"
          j.SslPolicy endpoint.alb_ssl_policy
        end
      end

      add_resource("AWS::ElasticLoadBalancingV2::TargetGroup", "DefaultTargetGroup") do |j|
        j.VpcId district.vpc_id
        j.Port 80
        j.Protocol "HTTP"
        j.Tags [
          tag("barcelona", district.name)
        ]
      end

      add_resource("AWS::Route53::RecordSet", "RecordSet") do |j|
        hosted_zone = district.aws.route53.get_hosted_zone(id: district.private_hosted_zone_id).hosted_zone
        j.HostedZoneId district.private_hosted_zone_id
        j.Name [endpoint.name,
                "endpoint",
                district.name,
                hosted_zone.name].join(".")
        j.TTL 300
        j.Type "CNAME"
        j.ResourceRecords [get_attr("LB", "DNSName")]
      end
    end

    private

    def district
      endpoint.district
    end

    def endpoint
      options[:endpoint]
    end

    def lb_scheme
      endpoint.public? ? 'internet-facing' : 'internal'
    end

    def lb_security_group
      endpoint.public? ? district.public_elb_security_group : district.private_elb_security_group
    end

    def lb_subnets
      district.subnets(endpoint.public? ? 'Public' : 'Private').map(&:subnet_id)
    end
  end

  class Stack < CloudFormation::Stack
    def initialize(endpoint)
      stack_name = "endpoint-#{endpoint.name}"
      options = {
        endpoint: endpoint
      }
      super(stack_name, options)
    end

    def build
      super do |builder|
        builder.add_builder Builder.new(self, options)
      end
    end

    def build_outputs(j)
      j.DNSName do |j|
        j.Value get_attr("LB", "DNSName")
      end
    end
  end

  belongs_to :district, inverse_of: :endpoints
  has_many :listeners, inverse_of: :endpoint
  has_many :services, through: :listeners
  has_many :review_groups, dependent: :destroy

  validates :name,
            presence: true,
            uniqueness: true,
            immutable: true,
            format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\z/ }
  validates :public, immutable: true
  validates :ssl_policy, inclusion: {in: %w(old intermediate modern)}, presence: true

  after_create :create_stack
  after_update :update_stack
  after_destroy :delete_stack

  after_initialize do |endpoint|
    endpoint.public = true if endpoint.public.nil?
    endpoint.ssl_policy ||= "intermediate"
  end

  def load_balancer_id
    cf_executor&.resource_ids["LB"]
  end

  def http_listener_id
    cf_executor&.resource_ids["LBListenerHTTP"]
  end

  def https_listener_id
    cf_executor&.resource_ids["LBListenerHTTPS"]
  end

  def dns_name
    cf_executor.outputs&.dig("DNSName")
  end

  def to_param
    name
  end

  def alb_ssl_policy
    {
      "old" => "ELBSecurityPolicy-TLS-1-0-2015-04",
      "intermediate" => "ELBSecurityPolicy-2016-08",
      "modern" => "ELBSecurityPolicy-TLS-1-2-2017-01"
    }[ssl_policy]
  end

  def cf_executor
    @cf_executor ||= begin
                       stack = Stack.new(self)
                       CloudFormation::Executor.new(stack, district.aws.cloudformation)
                     end
  end

  private

  def create_stack
    cf_executor.create
  end

  def update_stack
    cf_executor.update
  end

  def delete_stack
    cf_executor.delete
  end
end
