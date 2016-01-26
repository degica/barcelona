module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
      def build_resources
        # TODO CF doesn't support managed NAT gateway yet
        raise "nat resource is not supported"

        add_resource("AWS::EC2::EIP", "EIPForNAT#{options[:nat_id]}",
                     depends_on: ["VPCGatewayAttachment"]) do |j|
          j.Domain "vpc"
        end

        add_resource("AWS::EC2::NATGateway", "NAT#{options[:nat_id]}") do |j|
        end

        options[:route_table_logical_ids].each do |rt|
          add_resource("AWS::EC2::Route", "RouteNATFor#{rt}") do |j|
            j.RouteTableId ref(rt)
            j.DestinationCidrBlock "0.0.0.0"
            j.InstanceId ref("NAT#{options[:nat_id]}")
          end
        end
      end
    end
  end
end
