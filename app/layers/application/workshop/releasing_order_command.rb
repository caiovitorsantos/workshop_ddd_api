module Application
  module Workshop
    # Base for the commands that end an order before it is approved — the
    # customer rejecting the quote, or the workshop cancelling the order.
    #
    # Both do the same two things: give back every part the order was holding
    # (the reservation made by `AddPartToOrder`) and move the order to
    # `cancelled`. Only the aggregate command differs, so that is all a subclass
    # supplies.
    #
    # Like `ApproveQuote`, this is one transaction across two bounded contexts:
    # the status change and the stock release land together or not at all.
    class ReleasingOrderCommand < Application::Shared::UseCase
      include QuotedPartQuantities

      def initialize(orders:, parts:, transaction:, events:)
        @orders = orders
        @parts = parts
        @transaction = transaction
        @events = events
      end

      private

      attr_reader :orders, :parts, :transaction, :events

      def perform(id:, reason: nil)
        order, released_parts, saved = transaction.within do
          order = orders.find(id)
          raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

          # Status transition first: an order that cannot be cancelled (already
          # in progress, already closed) fails here, before any stock moves.
          apply(order, reason)
          released_parts = release_reserved_parts(order)
          [ order, released_parts, orders.save(order) ]
        end

        publish_events_of(order, *released_parts)
        saved
      end

      # Returns the parts it released, so their events can be published.
      def release_reserved_parts(order)
        quantities_by_part(order).map do |part_id, quantity|
          part = parts.find_for_update(part_id)
          raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

          part.release!(quantity, service_order_id: order.id)
          parts.save(part)
          part
        end
      end

      # Subclasses implement this and nothing else.
      def apply(order, reason)
        raise NotImplementedError, "#{self.class} does not implement #apply"
      end
    end
  end
end
