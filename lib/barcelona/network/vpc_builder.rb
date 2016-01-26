module Barcelona
  module Network
    class VPCBuilder < CloudFormation::Builder
      class UnsupportedNatType < StandardError; end

      def initialize(options)
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

        case options[:nat_type]
        when :managed_gateway then
          add_builder NatBuilder.new(route_table_logical_id: "RouteTableTrusted1")
        when :managed_gateway_multi_az then
          2.times do |az_index|
            add_builder NatBuilder.new(route_table_logical_id: "RouteTableTrusted#{az_index}")
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
            tag("Application", cf_stack_name)
          ]
        end

        add_resource("AWS::EC2::InternetGateway", "InternetGateway") do |j|
          j.Tags [
            tag("Name", cf_stack_name),
            tag("Application", cf_stack_name),
            tag("Network", "Public")
          ]
        end

        add_resource("AWS::EC2::VPCGatewayAttachment", "VPCGatewayAttachment") do |j|
          j.VpcId ref("VPC")
          j.InternetGatewayId ref("InternetGateway")
        end

        add_resource("AWS::EC2::DHCPOptions", "VPCDHCPOptions") do |j|
          j.DomainName join(" ", "ap-northeast-1.compute.internal", "bcn")
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
            }
          ]
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
        end

        add_resource("AWS::EC2::SecurityGroup", "ContainerInstanceAccessibleSecurityGroup") do |j|
          j.GroupDescription "accessible to container instances"
          j.VpcId ref("VPC")
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
              "IpProtocol" => -1,
              "FromPort" => -1,
              "ToPort" => -1,
              "CidrIp" => "0.0.0.0/0"
            }
          ]
        end

        if options[:bastion_key_pair]
          add_resource("AWS::EC2::Instance", "BastionServer",
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.InstanceType "t2.micro"
            j.SourceDestCheck false
            j.ImageId "ami-383c1956"
            j.KeyName options[:bastion_key_pair]
            j.NetworkInterfaces [
              {
                "AssociatePublicIpAddress" => true,
                "DeviceIndex" => 0,
                "SubnetId" => ref("SubnetDmz1"),
                "GroupSet" => [ref("SecurityGroupBastion")]
              }
            ]
            j.Tags [
              tag("Name", join("-", cf_stack_name, "bastion"))
            ]
          end
        end

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
                      "ec2:AssociateAddress",
                      "ec2:TerminateInstances",
                      "ec2:DescribeInstances",
                      "ecs:CreateCluster",
                      "ecs:DeregisterContainerInstance",
                      "ecs:DiscoverPollEndpoint",
                      "ecs:Poll",
                      "ecs:RegisterContainerInstance",
                      "ecs:StartTelemetrySession",
                      "ecs:Submit*",
                      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                      "elasticloadbalancing:DescribeLoadBalancers",
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
      end
    end
  end
end
