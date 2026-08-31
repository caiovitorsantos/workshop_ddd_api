module Domain
  module Inventory
    # Domain events published by the Part aggregate — the stickies from the
    # parts-and-consumables board (PLANO_TECH_CHALLENGE.md §2.7).
    module Events
      Event = Domain::Shared::DomainEvent

      # Parts consumed by an approved service order. Carries the order id so the
      # movement history can answer "which order took this part?".
      class StockDeducted < Event; end

      # Goods received from a supplier, or parts returned by a cancelled order.
      class StockReplenished < Event; end

      # The balance *crossed* below the reorder point. This is the trigger for
      # the replenishment policy, which is why it fires only on the crossing and
      # not on every movement while already below: an alert that repeats on
      # every deduction is an alert nobody reads.
      class PartBelowMinimum < Event; end
    end
  end
end
