module Application
  module Workshop
    # Use case: add a part to an order being assembled.
    #
    # This is where the first phase of the two-phase stock flow happens: the
    # part is **reserved**. Nothing leaves the shelf — quotes get rejected — but
    # the held amount stops another order from quoting stock already spoken for.
    # Approval turns the reservation into a deduction (`ApproveQuote`); a
    # rejected or cancelled order releases it (`RejectQuote`,
    # `CancelServiceOrder`).
    #
    # Reservation and the order line are one transaction across two bounded
    # contexts, like approval: a rollback has to undo both, or the order would
    # quote a part the shelf is not holding.
    class AddPartToOrder < Application::Shared::UseCase
      def initialize(orders:, parts:, transaction:)
        @orders = orders
        @parts = parts
        @transaction = transaction
      end

      private

      attr_reader :orders, :parts, :transaction

      def perform(id:, part_id:, quantity:)
        transaction.within do
          order = orders.find(id)
          raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

          part = parts.find_for_update(part_id)
          raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

          # Order first: it refuses (InvalidTransition) unless the order is still
          # a draft, and that check must happen before any stock is held.
          order.add_part(
            part_id: part.id, description: part.description,
            unit_price: part.unit_price, quantity: quantity
          )
          part.reserve!(quantity, service_order_id: order.id)

          parts.save(part)
          orders.save(order)
        end
      end
    end
  end
end
