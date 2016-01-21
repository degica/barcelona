module Barcelona::Network
  class NetworkStack < CloudFormation::Stack
    attr_accessor :name, :options

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def build
      super do |builder|
        builder.add_builder VPCBuilder.new(options)
      end
    end

    def build_outputs(json)
      json.VpcId do |j|
        j.Value ref("VPC")
      end
    end
  end
end
