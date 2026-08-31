module Application
  module Workshop
    # ==========================================================================
    # Use case: the customer approved the quote.
    # ==========================================================================
    #
    # **Pivotal event 3** (PLANO_TECH_CHALLENGE.md §2.5) turned into code, and
    # the most delicate operation in the system: it is the one place where two
    # bounded contexts have to change together.
    #
    #   Workshop  — the order moves to `in_progress`
    #   Inventory — every quoted part's reservation becomes a real deduction
    #
    # Both, or neither. The parts were already reserved when they were added to
    # the order (`AddPartToOrder`), so approval never fails for want of stock —
    # that check moved earlier. It can still fail on the status transition (an
    # order approved twice), and then the deductions roll back with it.
    #
    # This is the use case that justifies the Application layer existing. Neither
    # aggregate can coordinate this — ServiceOrder must not reach into Inventory,
    # and Part knows nothing about orders. Orchestration across aggregates is
    # exactly the job of this layer.
    class ApproveQuote < Application::Shared::UseCase
      include QuotedPartQuantities

      def initialize(orders:, parts:, id:)
        @orders = orders
        @parts = parts
        @id = id
      end

      private

      attr_reader :orders, :parts, :id

      def perform
        # One transaction spans both contexts. Rolling back undoes the stock
        # movements together with the status change — there is no window where
        # one landed and the other did not.
        ActiveRecord::Base.transaction do
          order = orders.find(id)
          raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

          # Status transition first: an order that cannot move to `in_progress`
          # (already approved, wrong state) fails here, before any stock moves.
          order.approve_quote!
          consume_reserved_parts(order)
          orders.save(order)
        end
      end

      def consume_reserved_parts(order)
        quantities_by_part(order).each do |part_id, quantity|
          # Locked, not merely read: two approvals touching the same part would
          # otherwise read the same balance and one deduction would be lost.
          part = parts.find_for_update(part_id)
          raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

          part.consume_reserved!(quantity, service_order_id: order.id)
          parts.save(part)
        end
      end
    end
  end
end
