class StackStringInput
  def initialize(inputspec)
    @inputspec = inputspec
  end

  def type
    String
  end

  def valid?(value)
    value.is_a?(String)
  end
end
