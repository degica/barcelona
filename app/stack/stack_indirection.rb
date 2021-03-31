class StackIndirection
  attr_reader :id
  def initialize(id)
    @id = id
  end

  def method_missing(name, *args, &block)
    StackReference.new(@id, name.to_s)
  end
end
