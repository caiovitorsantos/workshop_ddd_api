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

        render_page(orders, total, with: ServiceOrderPresenter.method(:summary))
      end

      def show
        render_found(
          container.orders.find(params[:id]), with: ServiceOrderPresenter, missing: "service order"
        )
      end

      def status
        render_found(
          container.orders.find(params[:id]),
          with: ServiceOrderPresenter.method(:status), missing: "service order"
        )
      end

      def create
        result = container.open_service_order.call(
          vehicle_id: params.require(:service_order).require(:vehicle_id)
        )

        respond_with(result, with: ServiceOrderPresenter, success: :created)
      end

      # --- Items -------------------------------------------------------------

      def add_service
        result = container.add_service_to_order.call(
          id: params[:id],
          service_id: item_params.require(:service_id),
          quantity: item_params.fetch(:quantity, 1)
        )

        respond_with(result, with: ServiceOrderPresenter)
      end

      def add_part
        result = container.add_part_to_order.call(
          id: params[:id],
          part_id: item_params.require(:part_id),
          quantity: item_params.require(:quantity)
        )

        respond_with(result, with: ServiceOrderPresenter)
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
        respond_with(use_case.call(id: params[:id], **input), with: ServiceOrderPresenter)
      end

      def item_params
        params.require(:item).permit(:service_id, :part_id, :quantity)
      end
    end
  end
end
