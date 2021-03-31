class StackResourceProcessor
  def initialize(stack_desc, options)
    @stack_desc = stack_desc
    @options = options

    @options[:inputs] ||= {}
  end

  def raw_script
    @raw_script ||= YAML.load(@stack_desc)
  end

  def hash_property(value)
    res = {}
    value.each do |key, value|
      res[key.camelize.to_sym] = properties(value)
    end

    res
  end

  def array_property(value)
    res = []
    value.each do |value|
      res << properties(value)
    end

    res
  end

  def number_property(value)
    value.to_s
  end

  def string_property(value)
    return evaluable_property(value) if evaluable?(value)

    value
  end

  def check_evaluable!(value)
    # This is far from secure, but we shouldn't be inserting code
    # we have no idea about anyway.
    regexes = [
      /[^A-Za-z0-9]+::([A-Za-z][A-Za-z0-9]*)/,
      /\.ancestor/,
      /\$/
    ] + Object.constants.map {|x| /#{x}\./ }

    regexes.each do |r|
      m = r.match(value)
      next if m.nil?

      raise InvalidConstantException, m
    end
  end

  def evaluable?(value)
    value.start_with?("{{") && value.end_with?("}}")
  end

  def evaluable_property(value)
    stripped = value[2..-3]
    check_evaluable!(value)

    result = StackDSL.new.instance_eval(stripped)
    properties(result)
  end

  def parameter_contents(id)
    @options[:inputs][id]
  end

  def parameter?(id)
    @options[:inputs]&.has_key?(id)
  end

  def stack_indirection_property(value)
    return parameter_contents(value.id) if parameter?(value.id)

    { "Ref" => value.id }
  end

  def stack_constant_property(value)
    @options[value.id]
  end

  def stack_reference_property(value)
    { "Fn::GetAtt" => [value.id, value.member] }
  end

  def properties(value)
    return hash_property(value) if value.is_a? Hash
    return array_property(value) if value.is_a? Array
    return number_property(value) if value.is_a? Integer
    return string_property(value) if value.is_a? String
    return stack_indirection_property(value) if value.is_a? StackIndirection
    return stack_constant_property(value) if value.is_a? StackConstant
    return stack_reference_property(value) if value.is_a? StackReference

    raise "Don't know how to do property #{value.inspect}"
  end

  def process_resource(value)
    type = value["type"]
    props = value.reject {|k,_| k == 'type'}.to_h

    {
      Type: type,
      Properties: properties(props)
    }
  end

  def input_names
    inputs.keys
  end

  def input_by_name(input_name)
    input = inputs[input_name]
    raise "No such input #{input_name}" if input.nil?
    input
  end

  def input_type(input_name)
    input_by_name(input_name).type
  end

  def input_valid?(input_name, input_value)
    input_by_name(input_name).valid?(input_value)
  end

  def input?(value)
    value["type"].start_with?("Barcelona::Input::")
  end

  def input_class(value)
    name = value["type"].sub(/^Barcelona::Input::/, '')
    "Stack#{name}Input".constantize
  end

  def inputs
    @inputs ||= begin
      res = {}
      raw_script.each do |key, value|
        next unless input?(value)

        res[key] = input_class(value).new(value)
      end
      res
    end
  end

  def check_inputs!
    underspecified = input_names - @options[:inputs].keys
    overspecified = @options[:inputs].keys - input_names

    raise "#{underspecified.join(", ")} not set" if underspecified.present?
    raise "#{overspecified.join(", ")} not a parameter" if overspecified.present? 
  end

  def resources
    check_inputs!
    res = {}

    raw_script.each do |key, value|
      next if input?(value)

      res[key.to_sym] = process_resource(value)
    end

    res
  end

  def outputs
    {}
  end
end
