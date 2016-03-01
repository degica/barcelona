module CloudFormation
  class Resource
    include Helper

    attr_accessor :name, :options

    def self.type(*args)
      args.empty? ? @@type : @@type = args[0]
    end

    def initialize(*args)
      @options = args.extract_options!
      @name, @type = args
    end

    def build(top_level, &block)
      top_level.__send__(name) do |j|
        define_resource(j, &block)
      end
    end

    def define_resource(json)
      json.Type type
      json.DependsOn options[:depends_on] if options[:depends_on]
      json.DeletionPolicy "Retain" if options[:retain]
      json.Properties do |j|
        yield j if block_given?
      end
    end

    def type
      @type || self.class.type
    end
  end
end
