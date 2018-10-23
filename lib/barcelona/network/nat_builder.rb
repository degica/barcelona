module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
      # https://aws.amazon.com/jp/amazon-linux-ami/
      # amzn-ami-vpc-nat-hvm-2018.03.0.20180811-x86_64-ebs
      VPC_NAT_AMI_IDS = {
        "us-east-1"      => "ami-0422d936d535c63b1",
        "us-east-2"      => "ami-0f9c61b5a562a16af",
        "us-west-1"      => "ami-0d4027d2cdbca669d",
        "us-west-2"      => "ami-40d1f038",
        "eu-west-1"      => "ami-0ea87e2bfa81ca08a",
        "eu-west-2"      => "ami-e6768381",
        "eu-west-3"      => "ami-0050bb60cea70c5b3",
        "eu-central-1"      => "ami-06465d49ba60cf770",
        "ap-northeast-1"      => "ami-0cf78ae724f63bac0",
        "ap-northeast-2"      => "ami-08cfa02141f9e9bee",
        "ap-southeast-1"      => "ami-0cf24653bcf894797",
        "ap-southeast-2"      => "ami-00c1445796bc0a29f",
        "ca-central-1"      => "ami-b61b96d2",
        "ap-south-1"      => "ami-0aba92643213491b9",
        "sa-east-1"      => "ami-09c013530239687aa",
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
