module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
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
          end

          add_resource("AWS::EC2::Instance", nat_name,
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.InstanceType options[:instance_type] || 't2.nano'
            j.SourceDestCheck false
            j.ImageId "ami-03cf3903"
            j.KeyName 'staging-bastion'
            j.NetworkInterfaces [
              {
                "AssociatePublicIpAddress" => true,
                "DeviceIndex" => 0,
                "SubnetId" => ref(options[:public_subnet_logical_id]),
                "GroupSet" => [ref("SecurityGroupNAT")]
              }
            ]
            j.Tags [
              tag("Application", cf_stack_name),
              tag("Name", join('-', cf_stack_name, nat_name))
            ]
          end
        when :managed_gateway
          # TODO CF doesn't support managed NAT gateway yet
          raise "Managed NAT resource is not supported"

          add_resource("AWS::EC2::EIP", "EIPFor#{nat_name}",
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.Domain "vpc"
          end

          add_resource("AWS::EC2::NATGateway", nat_name) do |j|
          end
        else
          raise "Unrecognized NAT type"
        end

        options[:route_table_logical_ids].each do |rt|
          add_resource("AWS::EC2::Route", "RouteNATFor#{rt}") do |j|
            j.RouteTableId ref(rt)
            j.DestinationCidrBlock "0.0.0.0/0"
            j.InstanceId ref(nat_name)
          end
        end
      end

      def nat_name
        "NAT#{options[:nat_id]}"
      end
    end
  end
end
