module Barcelona
  module Network
    class NatBuilder < CloudFormation::Builder
      def build_resources
        # TODO CF doesn't support managed NAT gateway yet
        raise "nat resource is not supported"

        add_resource("AWS::EC2::EIP", "EIPFor#{options[:route_table_logical_id]}",
                     depends_on: ["VPCGatewayAttachment"]) do |j|
          j.Domain "vpc"
        end

        add_resource("AWS::EC2::NATGateway", "NATFor#{options[:route_table_logical_id]}") do |j|
        end

        add_resource("AWS::EC2::Route", "RouteNAT") do |j|
          j.RouteTableId ref(options[:route_table_logical_id])
          j.DestinationCidrBlock "0.0.0.0"
          j.InstanceId ref("NATFor#{options[:route_table_logical_id]}")
        end
      end
    end
  end
end
