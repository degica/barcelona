class StackReference
  attr_reader :id, :member
  def initialize(id, member)
    @id = id
    @member = member
  end
end
