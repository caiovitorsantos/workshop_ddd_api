module Domain
  module Workshop
    # Internal entity of the ServiceOrder aggregate: a part or consumable fitted
    # to the vehicle. Like ServiceItem, the price is frozen when the item is
    # added.
    #
    # Stock is NOT deducted here. Inventory is a different aggregate in a
    # different context, and therefore a different transaction: the order
    # records the *intent* (part added to the quote), and the
    # Application::Workshop::ApproveQuote use case asks Inventory to deduct it.
    class PartItem < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      attr_reader :part_id, :description, :unit_price, :quantity

      def initialize(id: nil, part_id:, description:, unit_price:, quantity:)
        super(id: id)
        @part_id     = part_id
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
        raise Errors::InvalidValue, "part reference is required" if part_id.blank?
        raise Errors::InvalidValue, "part description is required" if description.blank?
        raise Errors::InvalidValue, "part quantity must be positive" unless quantity.positive?
      end
    end
  end
end
