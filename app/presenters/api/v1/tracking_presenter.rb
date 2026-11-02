module Api
  module V1
    # Output adapter for the public tracking endpoint — the only response the
    # API gives to someone without a token.
    #
    # The key set is the security boundary (TrackingController explains who is
    # on the other end, and spec/requests/api/v1/tracking_spec.rb pins these
    # exact keys). No money, no diagnosis, no customer and no plate: an
    # enumerator walking OS-000001 upwards must learn nothing worth harvesting.
    # Widening this hash is a security decision, not a formatting one.
    module TrackingPresenter
      def self.call(order)
        {
          number: order.number,
          status: order.status.to_s,
          status_label: order.status.label,
          # Portuguese: this is read by the customer, not by another system.
          waiting_on_you: order.status.awaiting_approval?,
          opened_at: order.opened_at,
          approved_at: order.approved_at,
          completed_at: order.completed_at,
          delivered_at: order.delivered_at
        }
      end
    end
  end
end
