module Barcelona::Network
  class PluginBuilder < CloudFormation::Builder
    delegate :district, to: :stack

    def build_resources
      district.hook_plugins(:network_stack_template, stack, top_level.attributes!)
    end
  end

  class NetworkStack < CloudFormation::Stack
    attr_accessor :district

    def initialize(district)
      @district = district
      options = {
        region: district.region,
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
        builder.add_builder VpcBuilder.new(self, options)
        builder.add_builder PluginBuilder.new(self, options)
      end
    end
  end
end
