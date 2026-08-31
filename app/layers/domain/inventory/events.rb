module Domain
  module Inventory
    # Domain events published by the Part aggregate — the stickies from the
    # parts-and-consumables board (PLANO_TECH_CHALLENGE.md §2.7).
    module Events
      Event = Domain::Shared::DomainEvent

      # A part was added to a service order and its stock is now held. The
      # physical balance has not moved; the held amount stops another order from
      # quoting stock already spoken for. Sticky: "Peças e insumos reservados".
      class StockReserved < Event; end

      # A held reservation was given back — the quote was rejected or the order
      # cancelled before approval. Sticky: "Peças e insumos liberados".
      class StockReleased < Event; end

      # A reservation could not be made: not enough available stock when a part
      # was added to an order. Recorded right before `reserve!` raises. Sticky:
      # "Estoque insuficiente".
      class InsufficientStockDetected < Event; end

      # Parts consumed by an approved service order — a reservation turned into a
      # real deduction. Carries the order id so the movement history can answer
      # "which order took this part?". Sticky: "Baixa de peças e insumos
      # reservados efetuada".
      class StockDeducted < Event; end

      # Goods received from a supplier, or parts returned by a cancelled order.
      class StockReplenished < Event; end

      # The balance *crossed* below the reorder point. This is the trigger for
      # the replenishment policy, which is why it fires only on the crossing and
      # not on every movement while already below: an alert that repeats on
      # every deduction is an alert nobody reads.
      class PartBelowMinimum < Event; end

      # Raised by the same crossing as PartBelowMinimum: once the part is below
      # its reorder point a purchase should be placed. Two stickies, one
      # trigger. Sticky: "Reabastecimento solicitado" — the supplier itself is
      # out of the MVP (PLANO_TECH_CHALLENGE.md §2.9), so nothing consumes this
      # yet; it exists to keep the board and the code in step.
      class ReplenishmentRequested < Event; end
    end
  end
end
