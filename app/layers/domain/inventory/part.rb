module Domain
  module Inventory
    # Part aggregate root: a part or consumable, and its balance on the shelf.
    #
    # The invariant that justifies this context existing: the balance never goes
    # negative. Callers command `deduct!` and get an error when there is not
    # enough stock — nobody writes `quantity -= n` from the outside.
    class Part < Domain::Shared::Entity
      include Domain::Shared::PublishesEvents

      Errors = Domain::Shared::Errors

      attr_reader :sku, :description, :unit_price, :quantity_on_hand, :minimum_stock

      def initialize(id: nil, sku:, description:, unit_price:,
                     quantity_on_hand: 0, minimum_stock: 0, clock: Time)
        super(id: id)
        @sku              = sku.to_s.strip.upcase
        @description      = description.to_s.strip
        @unit_price       = unit_price
        @quantity_on_hand = quantity_on_hand.to_i
        @minimum_stock    = minimum_stock.to_i
        @clock            = clock
        validate!
      end

      def available?(quantity)
        quantity_on_hand >= quantity.to_i
      end

      # Command: revise the catalogue details of the part.
      #
      # Note what is absent: `quantity_on_hand`. The balance is not an editable
      # field — it only ever moves through `deduct!` and `restock!`, each of
      # which enforces the invariant and publishes an event. Allowing a plain
      # edit would let stock appear and vanish with no movement history behind
      # it, which is exactly the problem this context exists to prevent.
      def revise(description: self.description, unit_price: self.unit_price,
                 minimum_stock: self.minimum_stock)
        self.class.new(
          id: id, sku: sku, description: description, unit_price: unit_price,
          quantity_on_hand: quantity_on_hand, minimum_stock: minimum_stock,
          clock: @clock
        )
      end

      def below_minimum?
        quantity_on_hand < minimum_stock
      end

      # Command: consume parts for an approved service order.
      #
      # `service_order_id` travels with the event so the movement history can
      # answer "which order took this part?" — the question the workshop asks
      # when a customer disputes a charge.
      def deduct!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        unless available?(quantity)
          raise Errors::BusinessRuleViolation,
                "insufficient stock for #{sku}: #{quantity_on_hand} on hand, #{quantity} requested"
        end

        was_below_minimum = below_minimum?
        @quantity_on_hand -= quantity

        record_event(Events::StockDeducted, quantity: quantity, service_order_id: service_order_id)
        announce_crossing_the_minimum(was_below_minimum)
        self
      end

      # Command: goods received, or parts returned by a cancelled order.
      def restock!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        @quantity_on_hand += quantity

        record_event(Events::StockReplenished, quantity: quantity, service_order_id: service_order_id)
        self
      end

      private

      # Fires only when the balance *crosses* the reorder point. Re-announcing
      # on every deduction while already below would turn the purchasing alert
      # into noise, and an alert nobody reads is worse than no alert.
      def announce_crossing_the_minimum(was_below_minimum)
        return if was_below_minimum || !below_minimum?

        record_event(
          Events::PartBelowMinimum,
          quantity_on_hand: quantity_on_hand, minimum_stock: minimum_stock
        )
      end

      def require_positive!(quantity)
        return if quantity.positive?

        raise Errors::InvalidValue, "stock movement quantity must be positive"
      end

      def validate!
        raise Errors::InvalidValue, "part SKU is required"          if sku.blank?
        raise Errors::InvalidValue, "part description is required"  if description.blank?
        raise Errors::InvalidValue, "stock cannot be negative"      if quantity_on_hand.negative?
        raise Errors::InvalidValue, "minimum stock cannot be negative" if minimum_stock.negative?
      end
    end
  end
end
