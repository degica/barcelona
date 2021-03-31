class InvalidConstantException < StandardError
  def initialize(m)
    super("The code '#{m}' is not permitted")
  end
end
