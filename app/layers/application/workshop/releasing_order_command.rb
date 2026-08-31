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

      def initialize(orders:, parts:, id:, reason: nil)
        @orders = orders
        @parts = parts
        @id = id
        @reason = reason
      end

      private

      attr_reader :orders, :parts, :id, :reason

      def perform
        ActiveRecord::Base.transaction do
          order = orders.find(id)
          raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

          # Status transition first: an order that cannot be cancelled (already
          # in progress, already closed) fails here, before any stock moves.
          apply(order)
          release_reserved_parts(order)
          orders.save(order)
        end
      end

      def release_reserved_parts(order)
        quantities_by_part(order).each do |part_id, quantity|
          part = parts.find_for_update(part_id)
          raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

          part.release!(quantity, service_order_id: order.id)
          parts.save(part)
        end
      end

      # Subclasses implement this and nothing else.
      def apply(order)
        raise NotImplementedError, "#{self.class} does not implement #apply"
      end
    end
  end
end
