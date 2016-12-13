module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
      # amzn-ami-vpc-nat-hvm-2016.09.0.20160923-x86_64-ebs
      VPC_NAT_AMI_IDS = {
        "us-east-1" => "ami-d2ee95c5",
        "us-east-2" => "ami-9fc299fa",
        "us-west-1" => "ami-90357bf0",
        "us-west-2" => "ami-c4469aa4",
        "eu-west-1" => "ami-d41d58a7",
        "eu-central-1" => "ami-b646bbd9",
        "ap-northeast-1" => "ami-831fcde2",
        "ap-southeast-1" => "ami-9c40e5ff",
        "ap-southeast-2" => "ami-addbebce",
        "ca-central-1" => "ami-a88735cc"
      }

      def build_resources
        case options[:type]
        when :instance then
          add_resource("AWS::EC2::SecurityGroup", "SecurityGroupNAT") do |j|
            j.GroupDescription "Security Group for NAT instances"
            j.VpcId ref("VPC")
            j.SecurityGroupIngress [
              {
                "IpProtocol" => -1,
                "FromPort" => -1,
                "ToPort" => -1,
                "CidrIp" => options[:vpc_cidr_block]
              }
            ]
            j.Tags [
              tag("barcelona", stack.district.name)
            ]
          end

          add_resource("AWS::EC2::Instance", nat_name,
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.InstanceType options[:instance_type] || 't2.nano'
            j.SourceDestCheck false
            j.ImageId VPC_NAT_AMI_IDS[stack.district.region]
            j.NetworkInterfaces [
              {
                "AssociatePublicIpAddress" => true,
                "DeviceIndex" => 0,
                "SubnetId" => ref(options[:public_subnet_logical_id]),
                "GroupSet" => [ref("SecurityGroupNAT")]
              }
            ]
            j.Tags [
              tag("barcelona", stack.district.name),
              tag("barcelona-role", "nat"),
              tag("Name", join('-', cf_stack_name, nat_name))
            ]
          end
        when :managed_gateway
          add_resource("AWS::EC2::EIP", eip_name,
                       retain: true,
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.Domain "vpc"
          end

          add_resource("AWS::EC2::NatGateway", nat_name) do |j|
            j.AllocationId get_attr(eip_name, "AllocationId")
            j.SubnetId ref(options[:public_subnet_logical_id])
          end
        else
          raise "Unrecognized NAT type"
        end

        options[:route_table_logical_ids].each do |rt|
          add_resource("AWS::EC2::Route", "RouteNATFor#{rt}") do |j|
            j.RouteTableId ref(rt)
            j.DestinationCidrBlock "0.0.0.0/0"
            case options[:type]
            when :instance
              j.InstanceId ref(nat_name)
            when :managed_gateway
              j.NatGatewayId ref(nat_name)
            end
          end
        end
      end

      def eip_name
        "EIPFor#{nat_name}"
      end

      def nat_name
        "NAT#{options[:type].to_s.classify}#{options[:nat_id]}"
      end
    end
  end
end
