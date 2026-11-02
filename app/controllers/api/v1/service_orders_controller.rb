module Api
  module V1
    # Service orders — the core subdomain's endpoints.
    #
    # Every status change is its own POST on a named business action, never a
    # PATCH on a `status` field. `POST /service_orders/1/approve_quote` says what
    # happened on the shop floor; `PATCH status=in_progress` says nothing, and
    # would hand the state machine to whoever calls the API.
    class ServiceOrdersController < BaseController
      def index
        orders, total = container.orders.list(
          page: page, per_page: per_page,
          status: params[:status], customer_id: params[:customer_id]
        )

        render json: {
          data: orders.map { |o| summarise(o) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def show
        order = container.orders.find(params[:id])
        return render_error("service order not found", :not_found) unless order

        render json: serialize(order)
      end

      def create
        result = container.open_service_order.call(
          vehicle_id: params.require(:service_order).require(:vehicle_id)
        )

        respond_with(result, success: :created) { |order| serialize(order) }
      end

      # --- Items -------------------------------------------------------------

      def add_service
        result = container.add_service_to_order.call(
          id: params[:id],
          service_id: item_params.require(:service_id),
          quantity: item_params.fetch(:quantity, 1)
        )

        respond_with(result) { |order| serialize(order) }
      end

      def add_part
        result = container.add_part_to_order.call(
          id: params[:id],
          part_id: item_params.require(:part_id),
          quantity: item_params.require(:quantity)
        )

        respond_with(result) { |order| serialize(order) }
      end

      # --- Life cycle commands -----------------------------------------------

      def start_diagnosis
        run(container.start_diagnosis)
      end

      def send_quote
        run(container.send_quote, diagnosis: params[:diagnosis])
      end

      # Approval, rejection and cancellation also move stock — the container
      # wires them to the parts repository as well; the controller need not know.
      def approve_quote
        run(container.approve_quote)
      end

      def reject_quote
        run(container.reject_quote, reason: params[:reason])
      end

      def complete
        run(container.complete_work)
      end

      def deliver
        run(container.deliver_vehicle)
      end

      def cancel
        run(container.cancel_service_order, reason: params[:reason])
      end

      private

      # Every life cycle command takes the order id plus, at most, one extra
      # input (a diagnosis, a reason).
      def run(use_case, **input)
        result = use_case.call(id: params[:id], **input)
        respond_with(result) { |order| serialize(order) }
      end

      def item_params
        params.require(:item).permit(:service_id, :part_id, :quantity)
      end

      # Listings do not need the items; a page of 25 orders would otherwise drag
      # a few hundred rows nobody is going to read.
      def summarise(order)
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

      def serialize(order)
        summarise(order).merge(
          diagnosis: order.diagnosis,
          quote: serialize_quote(order.quote),
          service_items: order.service_items.map { |i| serialize_item(i).merge(service_id: i.service_id) },
          part_items: order.part_items.map { |i| serialize_item(i).merge(part_id: i.part_id) },
          timeline: {
            opened_at: order.opened_at,
            approved_at: order.approved_at,
            started_at: order.started_at,
            completed_at: order.completed_at,
            delivered_at: order.delivered_at
          }
        )
      end

      def serialize_quote(quote)
        return nil if quote.nil?

        {
          labour_total: quote.labour_total.amount.to_s("F"),
          parts_total: quote.parts_total.amount.to_s("F"),
          total: quote.total.amount.to_s("F"),
          generated_at: quote.generated_at
        }
      end

      def serialize_item(item)
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
