module Backend::Ecs::V2
  class ServiceStack < CloudFormation::Stack
    class Builder < CloudFormation::Builder
      def build_resources
        add_resource("AWS::ECS::Service", "ECSService") do |j|
          j.Cluster district.name
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

            j.Role ref("ECSServiceRole")
            j.LoadBalancers [
              {
                "LoadBalancerName" => ref("ClassicLoadBalancer"),
                "ContainerPort" => container_port,
                "ContainerName" => container_name
              }
            ]
          elsif use_alb?
            j.Role ref("ECSServiceRole")
            j.LoadBalancers [
              {
                "TargetGroupArn" => ref("LBTargetGroup1"),
                "ContainerPort" => 80,
                "ContainerName" => "#{service.service_name}-revpro"
              }
            ]
          end
        end

        if use_tcp_load_balancer?
          build_service_role
          build_classic_elb
        elsif use_alb?
          build_service_role
          build_alb_listener
        end

        build_auto_scaling
      end

      def build_service_role
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
          j.Tags [
            tag("barcelona", district.name),
            tag("barcelona-heritage", service.heritage.name)
          ]
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

      def build_alb_listener
        add_resource("AWS::ElasticLoadBalancingV2::ListenerRule", "LBListenerRuleHTTP") do |j|
          j.Actions [{"TargetGroupArn" => ref("LBTargetGroup1"), "Type" => "forward"}]
          j.Conditions(listener.rule_conditions.map { |c| {"Field" => c["type"], "Values" => [c["value"]]} })
          j.ListenerArn listener.endpoint.http_listener_id
          j.Priority listener.rule_priority
        end

        if listener.endpoint.https_listener_id.present?
          add_resource("AWS::ElasticLoadBalancingV2::ListenerRule", "LBListenerRuleHTTPS") do |j|
            j.Actions [{"TargetGroupArn" => ref("LBTargetGroup1"), "Type" => "forward"}]
            j.Conditions(listener.rule_conditions.map { |c| {"Field" => c["type"], "Values" => [c["value"]]} })
            j.ListenerArn listener.endpoint.https_listener_id
            j.Priority listener.rule_priority
          end
        end

        add_resource("AWS::ElasticLoadBalancingV2::TargetGroup", "LBTargetGroup1") do |j|
          j.VpcId district.vpc_id
          j.HealthCheckIntervalSeconds listener.health_check_interval
          j.HealthCheckPath listener.health_check_path
          j.Matcher do |j|
            j.HttpCode "200-299"
          end
          j.Port 80
          j.Protocol "HTTP"
          j.TargetGroupAttributes [
            {"Key" => "deregistration_delay.timeout_seconds", "Value" => "60"}
          ]
          j.Tags [
            tag("barcelona", district.name)
          ]
        end
      end

      def build_auto_scaling
        add_resource("AWS::ApplicationAutoScaling::ScalableTarget", "ScalableTarget") do |j|
          j.MaxCapacity service.auto_scaling["max_count"]
          j.MinCapacity service.auto_scaling["min_count"]
          j.ResourceId join("/", "service", district.name, get_attr("ECSService", "Name"))
          j.RoleARN get_attr("AASRole", "Arn")
          j.ScalableDimension "ecs:service:DesiredCount"
          j.ServiceNamespace "ecs"
        end

        add_resource("AWS::ApplicationAutoScaling::ScalingPolicy", "ScaleUpPolicy") do |j|
          j.PolicyName "ScaleUpPolicy"
          j.PolicyType "StepScaling"
          j.ScalingTargetId ref("ScalableTarget")
          j.StepScalingPolicyConfiguration do |j|
            j.AdjustmentType "PercentChangeInCapacity"
            j.Cooldown 60
            j.MetricAggregationType "Average"
            j.MinAdjustmentMagnitude 1
            j.StepAdjustments [
              {"MetricIntervalLowerBound" => 0,  "MetricIntervalUpperBound" => 10, "ScalingAdjustment" => 0},
              {"MetricIntervalLowerBound" => 10, "MetricIntervalUpperBound" => 30, "ScalingAdjustment" => 10},
              {"MetricIntervalLowerBound" => 30,                                   "ScalingAdjustment" => 50}
            ]
          end
        end

        add_resource("AWS::ApplicationAutoScaling::ScalingPolicy", "ScaleDownPolicy") do |j|
          j.PolicyName "ScaleDownPolicy"
          j.PolicyType "StepScaling"
          j.ScalingTargetId ref("ScalableTarget")
          j.StepScalingPolicyConfiguration do |j|
            j.AdjustmentType "PercentChangeInCapacity"
            j.Cooldown 60
            j.MetricAggregationType "Average"
            j.MinAdjustmentMagnitude 1
            j.StepAdjustments [
              {                                   "MetricIntervalUpperBound" => -10, "ScalingAdjustment" => -10},
              {"MetricIntervalLowerBound" => -10, "MetricIntervalUpperBound" => 0, "ScalingAdjustment" => 0}
            ]
          end
        end

        add_resource("AWS::CloudWatch::Alarm", "ServiceCPUAlarm") do |j|
          j.ComparisonOperator "GreaterThanThreshold"
          j.AlarmActions [ref("ScaleUpPolicy")]
          j.OKActions [ref("ScaleDownPolicy")]
          j.EvaluationPeriods 1
          j.MetricName "CPUUtilization"
          j.Namespace "AWS/ECS"
          j.Period 180
          j.Statistic "Average"
          j.Threshold 50
          j.Dimensions [
            {"Name" => "ServiceName", "Value" => get_attr("ECSService", "Name")},
            {"Name" => "ClusterName", "Value" => district.name}
          ]
        end

        add_resource("AWS::IAM::Role", "AASRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2008-10-17"
            j.Statement [
              {
                "Effect" => "Allow",
                "Principal" => {
                  "Service" => ["application-autoscaling.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          end
          j.Path "/"
          j.Policies [
            {
              "PolicyName" => "aas-policy",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "ecs:DescribeServices",
                      "ecs:UpdateService",
                      "cloudwatch:DescribeAlarms"
                    ],
                    "Resource" => ["*"]
                  }
                ]
              }
            }
          ]
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
        !use_alb? && (service.port_mappings.present? || service.hosts.present?)
      end

      def use_alb?
        listener.present?
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
