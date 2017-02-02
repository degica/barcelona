module CloudFormation
  class Stack
    include Helper
    attr_accessor :name, :options

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def build
      Jbuilder.new do |j|
        j.Description description
        j.AWSTemplateFormatVersion "2010-09-09"

        j.Parameters do |j|
          build_parameters(j)
        end

        j.Resources do |j|
          builder = Builder.new(self)
          yield builder if block_given?
          builder.build(j)
        end

        j.Outputs do |j|
          build_outputs(j)
        end
      end
    end

    def build_parameters(json)
    end

    def build_outputs(json)
    end

    def target!
      build.target!
    end

    private

    def description
      "AWS CloudFormation for Barcelona #{name}"
    end
  end
end
