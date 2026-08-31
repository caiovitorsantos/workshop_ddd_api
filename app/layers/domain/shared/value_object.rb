module Domain
  module Shared
    # Value Object (Evans 2003; Vernon 2013):
    #
    #   - has no identifier; two instances are the same when their values are;
    #   - is immutable: change an attribute and you build a new object, you
    #     never mutate the existing one;
    #   - measures, quantifies or describes something in the domain;
    #   - is entirely replaceable.
    #
    # Subclasses declare their attributes with `.attributes` and enforce their
    # own rules in `validate!`. Immutability is guaranteed by freezing right
    # after construction, so an invalid or mutated value object cannot exist.
    class ValueObject
      class << self
        def attributes(*names)
          @attributes = names.freeze
          attr_reader(*names)
        end

        def attribute_names
          @attributes || []
        end
      end

      def initialize(**values)
        self.class.attribute_names.each do |name|
          instance_variable_set(:"@#{name}", values[name])
        end
        validate!
        freeze
      end

      # Equality by value, never by object identity.
      def ==(other)
        other.is_a?(self.class) && values == other.values
      end
      alias_method :eql?, :==

      def hash
        [ self.class, values ].hash
      end

      def values
        self.class.attribute_names.map { |name| public_send(name) }
      end

      def to_s
        values.join(" ")
      end

      private

      # Extension point: subclasses raise Errors::InvalidValue here.
      def validate!; end
    end
  end
end
