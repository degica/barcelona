module CloudFormation
  class Builder
    include Helper
    attr_accessor :top_level, :options, :children
    def initialize(options = {})
      @options = options
      @children = []
    end

    def build(top_level)
      @top_level = top_level
      build_resources
      children.each do |builder|
        builder.build(top_level)
      end
    end

    def build_resources
    end

    def add_builder(builder)
      self.children << builder
    end

    def add_resource(type_or_resource_class, name, options = {})
      resource = if type_or_resource_class.is_a? String
                   Resource.new(name, type_or_resource_class, options)
                 else
                   type_or_resource_class.new(name, options)
                 end
      resource.build(top_level) do |json|
        yield json if block_given?
      end
    end
  end
end
