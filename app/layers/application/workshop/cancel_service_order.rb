module Application
  module Workshop
    # Use case: the workshop ends the order — wrong vehicle, duplicate entry,
    # customer gave up before there was anything to quote.
    #
    # Deliberately distinct from RejectQuote: nobody refused a price here, and a
    # report on sales lost to price must not confuse the two.
    #
    # No parts are returned to stock, and that is not an omission. The state
    # machine only allows cancelling from `received`, `in_diagnosis` and
    # `awaiting_approval` — every state *before* approval, and approval is the
    # only thing that touches the shelf. Should the business ever ask to cancel
    # an order already in execution (PA-6), the restocking policy from PA-3 has
    # to be built at the same time; the two are one change, not two.
    class CancelServiceOrder < ServiceOrderCommand
      def initialize(repository:, id:, reason: nil)
        super(repository: repository, id: id)
        @reason = reason
      end

      private

      attr_reader :reason

      def apply(order) = order.cancel!(reason: reason)
    end
  end
end
