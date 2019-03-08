module Barcelona
  module Network
    # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html
    ELB_ACCOUNT_IDS = {
      "us-east-1"      => "127311923021",
      "us-east-2"      => "033677994240",
      "us-west-1"      => "027434742980",
      "us-west-2"      => "797873946194",
      "ca-central-1"   => "985666609251",
      "eu-west-1"      => "156460612806",
      "eu-central-1"   => "054676820928",
      "eu-west-2"      => "652711504416",
      "ap-northeast-1" => "582318560864",
      "ap-northeast-2" => "600734575887",
      "ap-southeast-1" => "114774131450",
      "ap-southeast-2" => "783225319266",
      "ap-south-1"     => "718504428378",
      "sa-east-1"      => "507241528517"
    }

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
          )
          add_builder SubnetBuilder.new(
            name: 'trusted',
            vpc_cidr_block: options[:cidr_block],
            public: false,
            az_index: az_index,
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

        add_builder BastionBuilder.new(options)

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
          j.ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
                               "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
                               "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
          j.Policies [
            {
              "PolicyName" => "barcelona-ecs-container-instance-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect" => "Allow",
                    "Action" => [
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

        add_resource("AWS::S3::BucketPolicy", "BucketPolicy") do |j|
          j.Bucket stack.district.s3_bucket_name
          j.PolicyDocument(
            {
              "Statement" => [
                {
                  "Action" => ["s3:PutObject"],
                  "Effect" => "Allow",
                  "Resource" => join("",
                                     "arn:aws:s3:::",
                                     "#{stack.district.s3_bucket_name}/elb_logs/*/AWSLogs/",
                                     ref("AWS::AccountId"),
                                     "/*"),
                  "Principal" => {
                    "AWS" => ELB_ACCOUNT_IDS[stack.district.region]
                  }
                }
              ]
            }
          )
        end
      end
    end
  end
end
