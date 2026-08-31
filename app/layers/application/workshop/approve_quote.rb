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
    #   Inventory — every quoted part leaves the shelf
    #
    # Both, or neither. If any part is short, the whole approval fails and the
    # customer is told why. An approved order whose parts do not exist is worse
    # than a refused approval: the workshop has promised work it cannot do.
    #
    # This is the use case that justifies the Application layer existing. Neither
    # aggregate can coordinate this — ServiceOrder must not reach into Inventory,
    # and Part knows nothing about orders. Orchestration across aggregates is
    # exactly the job of this layer, and nothing else here does more than shuffle
    # data between a repository and an aggregate.
    class ApproveQuote < Application::Shared::UseCase
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

          deduct_quoted_parts(order)

          order.approve_quote!
          orders.save(order)
        end
      end

      def deduct_quoted_parts(order)
        quantities_by_part(order).each do |part_id, quantity|
          # Locked, not merely read: two approvals racing for the last unit both
          # see "1 on hand" without this, both pass the check, and the shelf
          # goes to -1. `Part#deduct!` guards the invariant in memory; the lock
          # is what makes that guard mean anything under concurrency.
          part = parts.find_for_update(part_id)
          raise Domain::Shared::Errors::NotFound, "part #{part_id} not found" if part.nil?

          part.deduct!(quantity, service_order_id: order.id)
          parts.save(part)
        end
      end

      # Groups by part and locks in a stable order.
      #
      # Sorting is not cosmetic: two concurrent approvals that lock the same two
      # parts in opposite orders deadlock. Always taking locks in ascending
      # part_id order means one transaction simply waits for the other.
      #
      # Grouping also fixes a subtler bug: the same part can appear on two lines
      # of one order, and deducting each line separately would check availability
      # twice against a balance that only covers one.
      def quantities_by_part(order)
        order.part_items
             .group_by(&:part_id)
             .transform_values { |items| items.sum(&:quantity) }
             .sort_by { |part_id, _| part_id }
      end
    end
  end
end
