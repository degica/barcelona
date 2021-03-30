class StackDSL
  def initialize(describer)
    @describer = describer
  end

  module Barcelona
    VPC = :vpc_id
    DistrictName = :district_name
  end

  def constant(sym)
    @describer.options[sym]
  end
end

class StackDescriberService
  attr_reader :options

  def initialize(stack_desc, options)
    @stack_desc = stack_desc
    @options = options
  end

  def raw_script
    @raw_script ||= YAML.load(@stack_desc)
  end

  def hash_property(value)
    res = {}
    value.each do |key, value|
      res[key.to_sym] = properties(value)
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

  def evaluable?(value)
    value.start_with?("{{") && value.end_with?("}}")
  end

  def evaluable_property(value)
    stripped = value[2..-3]

    result = StackDSL.new(self).instance_eval(stripped)
    properties(result)
  end

  def properties(value)
    return hash_property(value) if value.is_a? Hash
    return array_property(value) if value.is_a? Array
    return number_property(value) if value.is_a? Integer
    return string_property(value) if value.is_a? String

    raise "Don't know how to do property #{value}"
  end

  def resources
    res = {}

    raw_script.each do |key, value|
      res[key.to_sym] = {
        Type: value["Type"],
        Properties: properties(value["Properties"])
      }
    end

    res
  end

  def outputs
    {}
  end

  def output
    {
      resources: resources,
      outputs: outputs
    }
  end
end
