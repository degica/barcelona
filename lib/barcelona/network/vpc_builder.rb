module Barcelona
  module Network
    class VPCBuilder < CloudFormation::Builder
      def initialize(options)
        super
        add_builder SubnetBuilder.new(
                      name: 'dmz',
                      vpc_cidr_block: options[:cidr_block],
                      public: true,
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

        add_resource("AWS::EC2::Instance", "BastionServer",
                     depends_on: ["VPCGatewayAttachment"]) do |j|
          j.InstanceType "t2.micro"
          j.SourceDestCheck false
          j.ImageId "ami-383c1956"
          j.KeyName options[:bastion_key_pair] if options[:bastion_key_pair]
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
    end
  end
end
