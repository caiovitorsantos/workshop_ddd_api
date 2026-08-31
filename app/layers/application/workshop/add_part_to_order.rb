module Application
  module Workshop
    # Use case: add a part to an order being assembled.
    #
    # **No stock is deducted here.** Putting a part on a quote is a statement of
    # intent, and quotes get rejected. The shelf is only touched when the
    # customer approves — see ApproveQuote.
    #
    # Availability is checked anyway, as a courtesy: quoting a part the workshop
    # does not have and cannot get wastes everyone's time. It is a *check*, not
    # a reservation, and the real guarantee happens at approval under a lock.
    class AddPartToOrder < Application::Shared::UseCase
      def initialize(orders:, parts:, id:, part_id:, quantity:)
        @orders = orders
        @parts = parts
        @id = id
        @part_id = part_id
        @quantity = quantity
      end

      private

      attr_reader :orders, :parts, :id, :part_id, :quantity

      def perform
        order = orders.find(id)
        raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

        part = parts.find(part_id)
        raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

        unless part.available?(quantity)
          raise Domain::Shared::Errors::BusinessRuleViolation,
                "only #{part.quantity_on_hand} of #{part.sku} in stock, #{quantity} requested"
        end

        order.add_part(
          part_id: part.id,
          description: part.description,
          unit_price: part.unit_price,
          quantity: quantity
        )

        orders.save(order)
      end
    end
  end
end
