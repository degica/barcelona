module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
      # https://aws.amazon.com/jp/amazon-linux-ami/
      # amzn-ami-vpc-nat-hvm
      VPC_NAT_AMI_IDS = {
        "us-east-1"      => "ami-00a9d4a05375b2763",
        "us-east-2"      => "ami-00d1f8201864cc10c",
        "us-west-1"      => "ami-097ad469381034fa2",
        "us-west-2"      => "ami-0b840e8a1ce4cdf15",
        "eu-west-1"      => "ami-024107e3e3217a248",
        "eu-west-2"      => "ami-0ca65a55561666293",
        "eu-west-3"      => "ami-0641e4dfc1427f114",
        "eu-central-1"      => "ami-06a5303d47fbd8c60",
        "ap-northeast-1"      => "ami-00d29e4cb217ae06b",
        "ap-northeast-2"      => "ami-0d98591cbf9ef1ffd",
        "ap-southeast-1"      => "ami-01514bb1776d5c018",
        "ap-southeast-2"      => "ami-062c04ec46aecd204",
        "ca-central-1"      => "ami-0b32354309da5bba5",
        "ap-south-1"      => "ami-00b3aa8a93dd09c13",
        "sa-east-1"      => "ami-057f5d52ff7ae75ae",
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
            j.InstanceType options[:instance_type] || 't3.nano'
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
            j.MetadataOptions do |m|
              m.HttpTokens 'required'
            end
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
