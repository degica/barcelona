module Barcelona
  module Network
    class VPCBuilder < CloudFormation::Builder
      class UnsupportedNatType < StandardError; end

      def initialize(*args)
        super
        2.times do |az_index|
          add_builder SubnetBuilder.new(
            name: 'dmz',
            vpc_cidr_block: options[:cidr_block],
            public: true,
            az_index: az_index,
            nat_type: nil,
            network_acl_entries: [
              {from: 22,   to: 22,    protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 80,   to: 80,    protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 443,  to: 443,   protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 1024, to: 65535, protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 1024, to: 65535, protocol: "udp", cidr: "0.0.0.0/0"},
              {from: 123,  to: 123,   protocol: "udp", cidr: "0.0.0.0/0"}
            ]
          )
          add_builder SubnetBuilder.new(
            name: 'trusted',
            vpc_cidr_block: options[:cidr_block],
            public: false,
            az_index: az_index,
            network_acl_entries: [
              {from: 22,   to: 22,    protocol: "tcp", cidr: "10.0.0.0/8"},
              {from: 80,   to: 80,    protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 443,  to: 443,   protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 1024, to: 65535, protocol: "tcp", cidr: "0.0.0.0/0"},
              {from: 1024, to: 65535, protocol: "udp", cidr: "0.0.0.0/0"},
              {from: 123,  to: 123,   protocol: "udp", cidr: "0.0.0.0/0"}
            ]
          )
        end

        add_builder AutoscalingBuilder.new(options[:autoscaling]) if options[:autoscaling]

        case options[:nat_type]
        when "instance" then
          add_builder NatBuilder.new(
            type: :instance,
            vpc_cidr_block: options[:cidr_block],
            public_subnet_logical_id: 'SubnetDmz1',
            instance_type: options[:nat_instance_type],
            nat_id: "1",
            route_table_logical_ids: %w(RouteTableTrusted1 RouteTableTrusted2))
        when "managed_gateway" then
          add_builder NatBuilder.new(
            type: :managed_gateway,
            vpc_cidr_block: options[:cidr_block],
            public_subnet_logical_id: 'SubnetDmz1',
            nat_id: "1",
            route_table_logical_ids: %w(RouteTableTrusted1 RouteTableTrusted2))
        when "managed_gateway_multi_az" then
          [1, 2].each do |az_index|
            add_builder NatBuilder.new(
              type: :managed_gateway,
              vpc_cidr_block: options[:cidr_block],
              public_subnet_logical_id: "SubnetDmz#{az_index}",
              nat_id: az_index.to_s,
              route_table_logical_ids: ["RouteTableTrusted#{az_index}"])
          end
        when nil then
        # Do not create NAT and route
        else
          raise UnsupportedNatType
        end
      end

      def build_resources
        add_resource("AWS::EC2::VPC", "VPC") do |j|
          j.CidrBlock options[:cidr_block]
          j.EnableDnsSupport true
          j.EnableDnsHostnames true
          j.Tags [
            tag("Name", cf_stack_name),
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::EC2::InternetGateway", "InternetGateway") do |j|
          j.Tags [
            tag("Name", cf_stack_name),
            tag("barcelona", stack.district.name),
            tag("Network", "Public")
          ]
        end

        add_resource("AWS::EC2::VPCGatewayAttachment", "VPCGatewayAttachment") do |j|
          j.VpcId ref("VPC")
          j.InternetGatewayId ref("InternetGateway")
        end

        add_resource("AWS::EC2::DHCPOptions", "VPCDHCPOptions") do |j|
          j.DomainName join(" ", "#{options[:region]}.compute.internal", "bcn")
          j.DomainNameServers ["AmazonProvidedDNS"]
        end

        add_resource("AWS::EC2::VPCDHCPOptionsAssociation", "VPCDHCPOptionsAssociation") do |j|
          j.VpcId ref("VPC")
          j.DhcpOptionsId ref("VPCDHCPOptions")
        end

        add_resource("AWS::Route53::HostedZone", "LocalHostedZone") do |j|
          j.Name "bcn"
          j.VPCs [
            {"VPCId" => ref("VPC"), "VPCRegion" => region}
          ]
        end

        add_resource("AWS::EC2::SecurityGroup", "PublicELBSecurityGroup") do |j|
          j.GroupDescription "SG for Public ELB"
          j.VpcId ref("VPC")
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 80,
              "ToPort" => 80,
              "CidrIp" => "0.0.0.0/0"
            },
            {
              "IpProtocol" => "tcp",
              "FromPort" => 443,
              "ToPort" => 443,
              "CidrIp" => "0.0.0.0/0"
            },
            {
              "IpProtocol" => "-1",
              "FromPort" => "-1",
              "ToPort" => "-1",
              "CidrIp" => options[:cidr_block]
            }
          ]
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::EC2::SecurityGroupEgress", "PublicELBSecurityGroupEgress") do |j|
          j.GroupId ref("PublicELBSecurityGroup")
          j.IpProtocol "tcp"
          j.FromPort 1
          j.ToPort 65535
          j.SourceSecurityGroupId ref("InstanceSecurityGroup")
        end

        add_resource("AWS::EC2::SecurityGroup", "PrivateELBSecurityGroup") do |j|
          j.GroupDescription "SG for Private ELB"
          j.VpcId ref("VPC")
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 1,
              "ToPort" => 65535,
              "CidrIp" => options[:cidr_block]
            }
          ]
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::EC2::SecurityGroupEgress", "PrivateELBSecurityGroupEgress") do |j|
          j.GroupId ref("PrivateELBSecurityGroup")
          j.IpProtocol "tcp"
          j.FromPort 1
          j.ToPort 65535
          j.SourceSecurityGroupId ref("InstanceSecurityGroup")
        end

        add_resource("AWS::EC2::SecurityGroup", "ContainerInstanceAccessibleSecurityGroup") do |j|
          j.GroupDescription "accessible to container instances"
          j.VpcId ref("VPC")
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::EC2::SecurityGroup", "InstanceSecurityGroup") do |j|
          j.GroupDescription "SG for ECS container instances"
          j.VpcId ref("VPC")
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "SourceSecurityGroupId" => ref("SecurityGroupBastion")
            },
            {
              "IpProtocol" => "icmp",
              "FromPort" => -1,
              "ToPort" => -1,
              "CidrIp" => options[:cidr_block]
            },
            {
              "IpProtocol" => -1,
              "FromPort" => -1,
              "ToPort" => -1,
              "SourceSecurityGroupId" => ref("PublicELBSecurityGroup")
            },
            {
              "IpProtocol" => -1,
              "FromPort" => -1,
              "ToPort" => -1,
              "SourceSecurityGroupId" => ref("PrivateELBSecurityGroup")
            },
            {
              "IpProtocol" => -1,
              "FromPort" => -1,
              "ToPort" => -1,
              "SourceSecurityGroupId" => ref("ContainerInstanceAccessibleSecurityGroup")
            }
          ]
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource("AWS::EC2::SecurityGroupIngress", "InstanceSecurityGroupSelfIngress") do |j|
          j.GroupId ref("InstanceSecurityGroup")
          j.IpProtocol(-1)
          j.FromPort(-1)
          j.ToPort(-1)
          j.SourceSecurityGroupId ref("InstanceSecurityGroup")
        end

        add_resource("AWS::EC2::SecurityGroup", "SecurityGroupBastion") do |j|
          j.GroupDescription "Security Group for bastion servers"
          j.VpcId ref("VPC")
          j.SecurityGroupIngress [
            {
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "CidrIp" => "0.0.0.0/0"
            },
            {
              "IpProtocol" => "udp",
              "FromPort" => 123,
              "ToPort" => 123,
              "CidrIp" => options[:cidr_block]
            }
          ]
          j.SecurityGroupEgress [
            {
              "IpProtocol" => "udp",
              "FromPort" => 123,
              "ToPort" => 123,
              "CidrIp" => '0.0.0.0/0'
            },
            {
              "IpProtocol" => "tcp",
              "FromPort" => 22,
              "ToPort" => 22,
              "CidrIp" => options[:cidr_block]
            },
            {
              "IpProtocol" => "tcp",
              "FromPort" => 80,
              "ToPort" => 80,
              "CidrIp" => '0.0.0.0/0'
            },
            {
              "IpProtocol" => "tcp",
              "FromPort" => 443,
              "ToPort" => 443,
              "CidrIp" => '0.0.0.0/0'
            }
          ]
          j.Tags [
            tag("barcelona", stack.district.name)
          ]
        end

        add_resource(BastionServer, "BastionServer",
                     district: stack.district,
                     depends_on: ["VPCGatewayAttachment"])

        add_resource("AWS::IAM::Role", "ECSServiceRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2012-10-17"
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
              "PolicyName" => "barcelona-ecs-container-instance-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "elasticloadbalancing:Describe*",
                      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
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

        add_resource("AWS::IAM::Role", "ECSInstanceRole") do |j|
          j.AssumeRolePolicyDocument do |j|
            j.Version "2012-10-17"
            j.Statement [
              {
                "Effect" => "Allow",
                "Principal" => {
                  "Service" => ["ec2.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          end
          j.Path "/"
          j.Policies [
            {
              "PolicyName" => "barcelona-ecs-container-instance-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
                      "ec2:DescribeInstances",
                      "ecs:DeregisterContainerInstance",
                      "ecs:DiscoverPollEndpoint",
                      "ecs:Poll",
                      "ecs:RegisterContainerInstance",
                      "ecs:StartTelemetrySession",
                      "ecs:Submit*",
                      "ecs:DescribeClusters",
                      "ecr:GetAuthorizationToken",
                      "ecr:BatchCheckLayerAvailability",
                      "ecr:GetDownloadUrlForLayer",
                      "ecr:BatchGetImage",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:DescribeLogStreams",
                      "logs:PutLogEvents",
                      "s3:Get*",
                      "s3:List*"
                    ],
                    "Resource" => ["*"]
                  }
                ]
              }
            }
          ]
        end

        add_resource("AWS::IAM::InstanceProfile", "ECSInstanceProfile") do |j|
          j.Path "/"
          j.Roles [ref("ECSInstanceRole")]
        end

        add_resource("AWS::SNS::Topic", "NotificationTopic") do |j|
          j.DisplayName "district-#{stack.district.name}-notification"
        end
      end
    end
  end
end
