# We require these explicitly because the DSL class needs to override
# const_missing, which will prevent the Rails autoloader from working
# inside its context.
require_relative 'stack_constant'
require_relative 'stack_indirection'

class StackDSL
  module Barcelona
    def self.const_missing(id)
      StackConstant.new(id.to_s.sub(/^Barcelona::/, '').underscore.to_sym)
    end
  end

  def self.const_missing(id)
    StackIndirection.new(id.to_s)
  end
end
