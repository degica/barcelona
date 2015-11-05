module Barcelona
  module Plugins
    class Base
      attr_accessor :district, :attributes

      def initialize(district, attributes)
        @district = district
        @attributes = attributes
      end

      def hook(trigger, origin, arg)
        method_name = "on_#{trigger}"
        send(method_name, origin, arg) if respond_to? method_name
      end
    end
  end
end
