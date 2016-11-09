module Backend::Ecs::V2
  class ServiceStack < CloudFormation::Stack
    class Builder < CloudFormation::Builder
      def build_resources
        add_resource("AWS::IAM::Role", "ECSServiceRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2008-10-17"
            j.Statement [
              {
                "Effect" => "Allow",
                "Principal" => {
                  "Service" => ["ecs.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          end
          j.Path "/"
          j.Policies [
            {
              "PolicyName" => "barcelona-ecs-service-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "elasticloadbalancing:Describe*",
                      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                      "elasticloadbalancing:DeregisterTargets",
                      "elasticloadbalancing:DescribeTargetGroups",
                      "elasticloadbalancing:DescribeTargetHealth",
                      "elasticloadbalancing:RegisterTargets",
                      "ec2:Describe*",
                      "ec2:AuthorizeSecurityGroupIngress"
                    ],
                    "Resource" => ["*"]
                  }
                ]
              }
            }
          ]
        end

        add_resource("AWS::ECS::Service", "ECSService") do |j|
          j.Cluster district.name
          j.Role ref("ECSServiceRole")
          j.TaskDefinition options[:task_definition]
          j.DesiredCount options[:desired_count]
          if use_tcp_load_balancer?
            port_mapping = service.port_mappings.lb_registerable.first
            container_name = service.service_name
            container_port = port_mapping.container_port
            if port_mapping.http? || port_mapping.https?
              container_name = "#{service.service_name}-revpro"
              container_port = port_mapping.lb_port
            end

            j.LoadBalancers [
              {
                "LoadBalancerName" => ref("ClassicLoadBalancer"),
                "ContainerPort" => container_port,
                "ContainerName" => container_name
              }
            ]
          end
        end

        if use_tcp_load_balancer?
          build_classic_elb
        end
      end

      def build_classic_elb
        add_resource("AWS::ElasticLoadBalancing::LoadBalancer", "ClassicLoadBalancer") do |j|
          scheme = service.public? ? "internet-facing" : "internal"
          subnets = district.subnets(service.public? ? "Public" : "Private")
          security_group = service.public? ? district.public_elb_security_group : district.private_elb_security_group
          j.LoadBalancerName "lb-#{service.service_name}"
          j.Subnets subnets.map(&:subnet_id)
          j.Scheme scheme
          j.SecurityGroups [security_group]
          j.CrossZone true
          j.HealthCheck do |j|
            j.Target "TCP:#{service.port_mappings.first.host_port}"
            j.Interval 5
            j.Timeout 4
            j.UnhealthyThreshold 2
            j.HealthyThreshold 2
          end
          j.Listeners(service.port_mappings.lb_registerable.map { |pm|
            {
              "Protocol" => "TCP",
              "LoadBalancerPort" => pm.lb_port,
              "InstanceProtocol" => "TCP",
              "InstancePort" => pm.host_port
            }
          })
          j.ConnectionDrainingPolicy do |j|
            j.Enabled true
            j.Timeout 60
          end

          # Enable ProxyProtocol for http/https host ports
          ports = service.port_mappings.where(protocol: %w(http https)).pluck(:host_port)
          ports += service.port_mappings.where(enable_proxy_protocol: true).pluck(:host_port)
          if ports.present?
            policy = {
              "PolicyType" => "ProxyProtocolPolicyType",
              "PolicyName" => "#{service.service_name}--ProxyProtocol",
              "InstancePorts" => ports,
              "Attributes" => [
                {"Name" => "ProxyProtocol", "Value" => true}
              ]
            }
            j.Policies [policy]
          end
        end

        add_resource("AWS::Route53::RecordSet", "RecordSet") do |j|
          hosted_zone = district.aws.route53.get_hosted_zone(id: district.private_hosted_zone_id).hosted_zone
          j.HostedZoneId district.private_hosted_zone_id
          j.Name [service.name,
                  service.heritage.name,
                  service.district.name,
                  hosted_zone.name].join(".")
          j.TTL 300
          j.Type "CNAME"
          j.ResourceRecords [get_attr("ClassicLoadBalancer", "DNSName")]
        end
      end

      def service
        options[:service]
      end

      def district
        service.district
      end

      def listener
        # For now we don't support multiple listeners
        service.listeners.first
      end

      def use_tcp_load_balancer?
        # Using port_mappings or hosts requires ELB run in TCP mode which is supported
        # only by Classic ELB. Only in the case above we use Classic ELB
        service.port_mappings.present? || service.hosts.present?
      end
    end

    def initialize(service, task_definition, desired_count)
      stack_name = "#{service.district.name}-#{service.service_name}"
      options = {
        service: service,
        task_definition: task_definition,
        desired_count: desired_count
      }
      super(stack_name, options)
    end

    def build
      super do |builder|
        builder.add_builder Builder.new(self, options)
      end
    end
  end
end
