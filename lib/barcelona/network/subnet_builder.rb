module Barcelona
  module Network
    class SubnetBuilder < CloudFormation::Builder
      PROTOCOL_MAP = {
        icmp: 1,
        igmp: 2,
        tcp: 6,
        udp: 17,
        all: -1
      }

      def build_resources
        add_resource("AWS::EC2::RouteTable", route_table_name) do |j|
          j.VpcId ref("VPC")
          j.Tags [
            tag("Name", join("-", cf_stack_name, network_type)),
            tag("barcelona", stack.district.name),
            tag("Network", network_type.camelize)
          ]
        end

        if public?
          add_resource("AWS::EC2::Route", "Route#{name.camelize}",
                       depends_on: ["VPCGatewayAttachment"]) do |j|
            j.RouteTableId ref(route_table_name)
            j.DestinationCidrBlock "0.0.0.0/0"
            j.GatewayId ref("InternetGateway")
          end
        end

        add_resource("AWS::EC2::NetworkAcl", network_acl_name) do |j|
          j.VpcId ref("VPC")
          j.Tags [
            tag("Name", join("-", cf_stack_name, network_type)),
            tag("barcelona", stack.district.name),
            tag("Network", network_type.camelize)
          ]
        end

        network_acl_entries.each_with_index do |entry, i|
          add_resource("AWS::EC2::NetworkAclEntry",
                       "InboundNetworkAclEntry#{name.camelize}#{i}") do |j|
            j.NetworkAclId ref(network_acl_name)
            j.RuleNumber 100 + i
            j.RuleAction "allow"
            j.Egress false
            j.CidrBlock entry[:cidr]
            j.PortRange do |j|
              j.From entry[:from]
              j.To entry[:to]
            end
            protocol = entry[:protocol] || :tcp
            j.Protocol PROTOCOL_MAP[protocol.to_sym]
          end
        end

        add_resource("AWS::EC2::NetworkAclEntry",
                     "InboundNetworkAclEntry#{name.camelize}ICMP") do |j|
          j.NetworkAclId ref(network_acl_name)
          j.RuleNumber 200
          j.RuleAction "allow"
          j.Egress false
          j.CidrBlock "0.0.0.0/0"
          j.Icmp do |j|
            j.Type(-1)
            j.Code(-1)
          end
          j.Protocol PROTOCOL_MAP[:icmp]
        end

        add_resource("AWS::EC2::NetworkAclEntry",
                     "OutboundNetworkAclEntry#{name.camelize}") do |j|
          j.NetworkAclId ref(network_acl_name)
          j.RuleNumber 100
          j.Protocol(-1)
          j.RuleAction "allow"
          j.Egress true
          j.CidrBlock "0.0.0.0/0"
          j.PortRange do |j|
            j.From 0
            j.To 65535
          end
        end

        add_resource("AWS::EC2::Subnet", subnet_name) do |j|
          j.VpcId ref("VPC")
          j.CidrBlock subnet_cidr_block
          j.AvailabilityZone select(az_index, azs)
          j.Tags [
            tag("Name", join("-", cf_stack_name, name.camelize)),
            tag("barcelona", stack.district.name),
            tag("Network", network_type.camelize)
          ]
        end

        add_resource("AWS::EC2::SubnetRouteTableAssociation",
                     "SubnetRouteTableAssociation#{name.camelize}") do |j|
          j.SubnetId ref(subnet_name)
          j.RouteTableId ref(route_table_name)
        end

        add_resource("AWS::EC2::SubnetNetworkAclAssociation",
                     "SubnetNetworkAclAssociation#{name.camelize}") do |j|
          j.SubnetId ref(subnet_name)
          j.NetworkAclId ref(network_acl_name)
        end
      end

      def network_acl_name
        "NetworkAcl#{name.camelize}"
      end

      def network_acl_entries
        options[:network_acl_entries]
      end

      def subnet_name
        "Subnet#{name.camelize}"
      end

      def route_table_name
        "RouteTable#{name.camelize}"
      end

      def vpc_cidr_block
        options[:vpc_cidr_block]
      end

      def subnet_cidr_block
        base = public? ? 128 : 0 # 16th bit is public flag
        base += options[:az_index] + 1 # 22-23th bits are AZ ID
        base = base << 8
        (IPAddr.new(vpc_cidr_block) | base).to_s + '/24'
      end

      def name
        @name ||= options[:name] + (az_index + 1).to_s
      end

      def az_index
        options[:az_index]
      end

      def network_type
        public? ? "public" : "private"
      end

      def nat_type
        return nil if public?
        options[:nat_type] # 'instance' or 'gateway'
      end

      def public?
        options[:public]
      end
    end
  end
end
