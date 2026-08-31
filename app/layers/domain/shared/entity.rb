module Domain
  module Shared
    # Entity (Evans 2003):
    #
    #   - has a unique, stable identifier;
    #   - is mutable: it can and should change state after creation;
    #   - two entities are equal when they share an id, even if every other
    #     attribute differs.
    #
    # Entities here are plain Ruby objects. No ActiveRecord in this layer:
    # persistence belongs to Infrastructure, reached through repository ports.
    class Entity
      attr_reader :id

      def initialize(id: nil)
        @id = id
      end

      def ==(other)
        other.is_a?(self.class) && !id.nil? && id == other.id
      end
      alias_method :eql?, :==

      def hash
        [ self.class, id ].hash
      end

      # An entity without an id has not been persisted yet.
      def new_record?
        id.nil?
      end
    end
  end
end
