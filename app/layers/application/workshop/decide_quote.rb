module Application
  module Workshop
    # Use case: an external system reports the customer's decision on a quote.
    #
    # No new rule: the decision is handed to ApproveQuote or RejectQuote, which
    # already know how to move the order and the stock. What this adds is what
    # a webhook needs — finding the order by the number the customer saw, and
    # **idempotency**: callers retry, so a decision already applied answers
    # with the order as it stands instead of failing. A contradicting decision
    # still fails, as an InvalidTransition from the state machine.
    #
    # It returns the Result of the command it delegates to, so it is a plain
    # object with #call rather than a UseCase subclass.
    class DecideQuote
      Result = Application::Shared::Result

      def initialize(orders:, approve_quote:, reject_quote:)
        @orders = orders
        @approve_quote = approve_quote
        @reject_quote = reject_quote
      end

      def call(order_number:, decision:, reason: nil)
        order = orders.find_by_number(order_number)
        return Result.failure("service order #{order_number} not found", code: :not_found) if order.nil?

        case decision
        when "approved"
          order.approved_at ? Result.ok(order) : approve_quote.call(id: order.id)
        when "rejected"
          # Only an unapproved order can be cancelled, so cancelled-and-never-
          # approved is the state a rejection leaves behind. (A workshop
          # cancellation looks the same; answering 200 to it changes nothing.)
          order.status.cancelled? ? Result.ok(order) : reject_quote.call(id: order.id, reason: reason)
        else
          Result.failure("decision must be 'approved' or 'rejected'", code: :invalid_value)
        end
      end

      private

      attr_reader :orders, :approve_quote, :reject_quote
    end
  end
end
