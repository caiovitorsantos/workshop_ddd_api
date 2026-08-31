module Domain
  module Inventory
    # Part aggregate root: a part or consumable, and its balance on the shelf.
    #
    # The invariant that justifies this context existing: the balance never goes
    # negative. Stock moves in two phases — `reserve!` holds it when a part is
    # added to a service order, `consume_reserved!` turns the hold into a real
    # deduction when the quote is approved, `release!` gives it back if the
    # quote is rejected or the order is cancelled before approval. `restock!` is
    # the only way it goes up. Nobody writes `quantity -= n` from the outside.
    class Part < Domain::Shared::Entity
      include Domain::Shared::PublishesEvents

      Errors = Domain::Shared::Errors

      attr_reader :sku, :description, :unit_price, :quantity_on_hand,
                  :quantity_reserved, :minimum_stock

      def initialize(id: nil, sku:, description:, unit_price:,
                     quantity_on_hand: 0, quantity_reserved: 0, minimum_stock: 0,
                     clock: Time)
        super(id: id)
        @sku               = sku.to_s.strip.upcase
        @description       = description.to_s.strip
        @unit_price        = unit_price
        @quantity_on_hand  = quantity_on_hand.to_i
        @quantity_reserved = quantity_reserved.to_i
        @minimum_stock     = minimum_stock.to_i
        @clock             = clock
        validate!
      end

      # What a fresh reservation is checked against: the physical balance minus
      # the stock already promised to open orders.
      def available_quantity
        quantity_on_hand - quantity_reserved
      end

      def available?(quantity)
        available_quantity >= quantity.to_i
      end

      # Command: revise the catalogue details of the part.
      #
      # Note what is absent: `quantity_on_hand` and `quantity_reserved`. Neither
      # is an editable field — they only move through the stock commands, each
      # of which enforces the invariant and publishes an event. A plain edit
      # would let stock appear and vanish with no movement history behind it.
      def revise(description: self.description, unit_price: self.unit_price,
                 minimum_stock: self.minimum_stock)
        self.class.new(
          id: id, sku: sku, description: description, unit_price: unit_price,
          quantity_on_hand: quantity_on_hand, quantity_reserved: quantity_reserved,
          minimum_stock: minimum_stock, clock: @clock
        )
      end

      def below_minimum?
        quantity_on_hand < minimum_stock
      end

      # Command: hold stock for a part just added to a service order.
      #
      # Nothing leaves the shelf — the physical balance is untouched — but the
      # held amount stops another order from quoting stock already spoken for.
      # Refuses, and records why, when there is not enough available.
      def reserve!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        unless available?(quantity)
          record_event(
            Events::InsufficientStockDetected,
            sku: sku, requested: quantity, available: available_quantity
          )
          raise Errors::BusinessRuleViolation,
                "insufficient stock for #{sku}: #{available_quantity} available, #{quantity} requested"
        end

        @quantity_reserved += quantity
        record_event(Events::StockReserved, quantity: quantity, service_order_id: service_order_id)
        self
      end

      # Command: the quote was approved — turn a reservation into a deduction.
      #
      # Both balances drop together, so `available_quantity` is unchanged and
      # the reorder-point check now sees the smaller physical balance.
      def consume_reserved!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        if quantity > quantity_reserved
          raise Errors::BusinessRuleViolation,
                "cannot consume #{quantity} of #{sku}: only #{quantity_reserved} reserved"
        end

        was_below_minimum = below_minimum?
        @quantity_on_hand  -= quantity
        @quantity_reserved -= quantity

        record_event(Events::StockDeducted, quantity: quantity, service_order_id: service_order_id)
        announce_crossing_the_minimum(was_below_minimum)
        self
      end

      # Command: the quote was rejected or the order cancelled before approval —
      # give the held stock back. The physical balance never moved, so this only
      # lowers the reserved amount.
      def release!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        if quantity > quantity_reserved
          raise Errors::BusinessRuleViolation,
                "cannot release #{quantity} of #{sku}: only #{quantity_reserved} reserved"
        end

        @quantity_reserved -= quantity
        record_event(Events::StockReleased, quantity: quantity, service_order_id: service_order_id)
        self
      end

      # Command: consume parts for an approved service order.
      #
      # Superseded by the two-phase reserve! / consume_reserved! pair; kept until
      # every caller has migrated.
      def deduct!(quantity, service_order_id: nil)
        quantity = quantity.to_i
        require_positive!(quantity)

        unless quantity_on_hand >= quantity
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

      # Fires only when the balance *crosses* the reorder point. On the crossing
      # the workshop needs to know the part is low (PartBelowMinimum) and that a
      # purchase should be raised (ReplenishmentRequested) — two stickies, one
      # trigger. Re-announcing on every deduction while already below would turn
      # the purchasing alert into noise, and an alert nobody reads is worse than
      # no alert.
      def announce_crossing_the_minimum(was_below_minimum)
        return if was_below_minimum || !below_minimum?

        details = { quantity_on_hand: quantity_on_hand, minimum_stock: minimum_stock }
        record_event(Events::PartBelowMinimum, **details)
        record_event(Events::ReplenishmentRequested, **details)
      end

      def require_positive!(quantity)
        return if quantity.positive?

        raise Errors::InvalidValue, "stock movement quantity must be positive"
      end

      def validate!
        raise Errors::InvalidValue, "part SKU is required"             if sku.blank?
        raise Errors::InvalidValue, "part description is required"     if description.blank?
        raise Errors::InvalidValue, "stock cannot be negative"        if quantity_on_hand.negative?
        raise Errors::InvalidValue, "reserved stock cannot be negative" if quantity_reserved.negative?
        if quantity_reserved > quantity_on_hand
          raise Errors::InvalidValue, "reserved stock cannot exceed stock on hand"
        end
        raise Errors::InvalidValue, "minimum stock cannot be negative" if minimum_stock.negative?
      end
    end
  end
end
