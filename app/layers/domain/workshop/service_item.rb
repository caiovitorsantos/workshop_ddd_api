module Domain
  module Workshop
    # Internal entity of the ServiceOrder aggregate: a requested labour item
    # (oil change, wheel alignment, ...).
    #
    # `unit_price` and `description` are a *copy* of what the Catalog said at
    # the moment the item was added. If the catalog raises its prices tomorrow,
    # an already approved quote must not change by itself — which is why the
    # order freezes the value here instead of reading the catalog on render.
    class ServiceItem < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      attr_reader :service_id, :description, :unit_price, :quantity

      def initialize(id: nil, service_id:, description:, unit_price:, quantity: 1)
        super(id: id)
        @service_id  = service_id
        @description = description.to_s.strip
        @unit_price  = unit_price
        @quantity    = quantity.to_i
        validate!
      end

      def total
        unit_price * quantity
      end

      private

      def validate!
        raise Errors::InvalidValue, "service reference is required" if service_id.blank?
        raise Errors::InvalidValue, "service description is required" if description.blank?
        raise Errors::InvalidValue, "service quantity must be positive" unless quantity.positive?
      end
    end
  end
end
