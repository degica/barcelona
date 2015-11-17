module Barcelona
  module Plugins
    class Base
      attr_accessor :model
      delegate :district, to: :model

      def initialize(model)
        @model = model
      end

      def hook(trigger, origin, arg)
        method_name = "on_#{trigger}"
        if respond_to? method_name
          send(method_name, origin, arg)
        else
          arg
        end
      end

      def attributes
        model.plugin_attributes
      end
    end
  end
end
