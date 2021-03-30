class StackBuilderService
  class GenericBuilder < CloudFormation::Builder
    def initialize(raw_desc, stack, options)
      @raw_desc = raw_desc
      super(stack, options)
    end

    def raw_stack
      @raw_stack ||= StackDescriberService.new(@raw_desc, options).output
    end

    def build_resources
      outer_options = options
      raw_stack[:resources].each do |name, info|
        add_resource(info[:Type], name.to_s) do |j|
          info[:Properties].each do |propname, propval|
            j.set!(propname, propval)
          end
          j.Tags [
            tag("barcelona", outer_options[:district_name])
          ]
        end
      end
    end
  end

  class GenericStack < CloudFormation::Stack
    attr_accessor :district

    def initialize(name, district, stack_desc)
      @district = district
      @stack_desc = stack_desc
      super("#{district.stack_name}-#{name}", {
        district_name: name,
        vpc_id: district.vpc_id
      })
    end

    def build
      super do |builder|
        builder.add_builder GenericBuilder.new(@stack_desc, self, options)
      end
    end
  end

  def initialize(district)
    @district = district
  end

  def build(name, stack_desc)
    stack = GenericStack.new(name, @district, stack_desc)
    executor = CloudFormation::Executor.new(stack, @district)
    executor.create_or_update
  end
end
