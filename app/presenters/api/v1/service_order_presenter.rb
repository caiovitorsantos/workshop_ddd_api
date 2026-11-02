module Api
  module V1
    # Output adapter: how the API shows a Domain::Workshop::ServiceOrder.
    #
    # Two shapes, for two jobs:
    #
    #   summary — one line of a listing. Leaves the items out: a page of 25
    #             orders would otherwise drag a few hundred rows nobody reads.
    #   status  — just where the order stands, for GET /service_orders/:id/status.
    #   call    — the full order, with the quote, its lines and the timeline.
    module ServiceOrderPresenter
      module_function

      def summary(order)
        {
          id: order.id,
          number: order.number,
          status: order.status.to_s,
          status_label: order.status.label,
          customer_id: order.customer_id,
          vehicle_id: order.vehicle_id,
          total: order.quote&.total&.amount&.to_s("F"),
          opened_at: order.opened_at
        }
      end

      def status(order) = summary(order).slice(:id, :number, :status, :status_label)

      def call(order)
        summary(order).merge(
          diagnosis: order.diagnosis,
          quote: quote(order.quote),
          service_items: order.service_items.map { |i| item(i).merge(service_id: i.service_id) },
          part_items: order.part_items.map { |i| item(i).merge(part_id: i.part_id) },
          timeline: {
            opened_at: order.opened_at,
            approved_at: order.approved_at,
            started_at: order.started_at,
            completed_at: order.completed_at,
            delivered_at: order.delivered_at
          }
        )
      end

      def quote(quote)
        return nil if quote.nil?

        {
          labour_total: quote.labour_total.amount.to_s("F"),
          parts_total: quote.parts_total.amount.to_s("F"),
          total: quote.total.amount.to_s("F"),
          generated_at: quote.generated_at
        }
      end

      def item(item)
        {
          id: item.id,
          description: item.description,
          unit_price: item.unit_price.amount.to_s("F"),
          quantity: item.quantity,
          total: item.total.amount.to_s("F")
        }
      end
    end
  end
end
