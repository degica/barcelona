class StackDescriberService
  def initialize(stack_desc, options)
    @stack_desc = stack_desc
    @options = options
  end

  def output
    {
      resources: srp.resources,
      outputs: srp.outputs
    }
  end

  private

  def srp
    @srp ||= StackResourceProcessor.new(@stack_desc, @options)
  end
end
