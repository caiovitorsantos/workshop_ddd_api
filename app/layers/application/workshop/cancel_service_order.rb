module Application
  module Workshop
    # Use case: the workshop ends the order — wrong vehicle, duplicate entry,
    # customer gave up before there was anything to quote.
    #
    # Deliberately distinct from `RejectQuote`: nobody refused a price here, and
    # a report on sales lost to price must not confuse the two.
    #
    # Any parts already reserved (a part can be added while the order is still a
    # draft) are released back to the shelf. Nothing reserved yet — the common
    # case for a duplicate entry caught early — makes this a no-op on inventory.
    #
    # The state machine only allows cancelling from `received`, `in_diagnosis`
    # and `awaiting_approval` — every state *before* approval, and approval is
    # the only thing that turns a reservation into a deduction. So this only
    # ever releases reservations, never restocks a real deduction. Cancelling an
    # order already in execution (PA-6) would need the restock counterpart built
    # alongside it.
    class CancelServiceOrder < ReleasingOrderCommand
      private

      def apply(order) = order.cancel!(reason: reason)
    end
  end
end
