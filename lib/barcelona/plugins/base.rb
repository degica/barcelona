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
        send(method_name, origin, arg) if respond_to? method_name
      end

      def attributes
        model.plugin_attributes
      end
    end
  end
end
