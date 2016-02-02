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
        j.Description "AWS CloudFormation for Barcelona network stack"
        j.AWSTemplateFormatVersion "2010-09-09"
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

    def build_outputs(json)
    end

    def target!
      build.target!
    end
  end
end
