module Barcelona::Network
  class NetworkStack < CloudFormation::Stack
    attr_accessor :district

    def initialize(district)
      @district = district
      options = {
        cidr_block: district.cidr_block,
        bastion_key_pair: district.bastion_key_pair,
        nat_type: district.nat_type,
        autoscaling: {
          container_instance: ContainerInstance.new(district),
          instance_type: district.cluster_instance_type,
          desired_capacity: district.cluster_size
        }
      }
      super(district.stack_name, options)
    end

    def build
      super do |builder|
        builder.add_builder VPCBuilder.new(self, options)
      end
    end

    def build_outputs(json)
      json.VpcId do |j|
        j.Value ref("VPC")
      end
    end
  end
end
