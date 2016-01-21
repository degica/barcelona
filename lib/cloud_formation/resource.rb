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
        j.Type type
        j.DependsOn options[:depends_on] if options[:depends_on]
        j.Properties do |j|
          if respond_to? :define_properties
            define_properties(j, &block)
          end
          yield j if block_given?
        end
      end
    end

    def type
      @type || self.class.type
    end
  end
end
