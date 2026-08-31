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
        orders, total = order_repository.list(
          page: page, per_page: per_page,
          status: params[:status], customer_id: params[:customer_id]
        )

        render json: {
          data: orders.map { |o| summarise(o) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def show
        order = order_repository.find(params[:id])
        return render_error("service order not found", :not_found) unless order

        render json: serialize(order)
      end

      def create
        result = Application::Workshop::OpenServiceOrder.call(
          orders: order_repository,
          vehicles: vehicle_repository,
          customers: customer_repository,
          vehicle_id: params.require(:service_order).require(:vehicle_id)
        )

        respond_with(result, success: :created) { |order| serialize(order) }
      end

      # --- Items -------------------------------------------------------------

      def add_service
        result = Application::Workshop::AddServiceToOrder.call(
          orders: order_repository, services: service_repository,
          id: params[:id],
          service_id: item_params.require(:service_id),
          quantity: item_params.fetch(:quantity, 1)
        )

        respond_with(result) { |order| serialize(order) }
      end

      def add_part
        result = Application::Workshop::AddPartToOrder.call(
          orders: order_repository, parts: part_repository,
          id: params[:id],
          part_id: item_params.require(:part_id),
          quantity: item_params.require(:quantity)
        )

        respond_with(result) { |order| serialize(order) }
      end

      # --- Life cycle commands -----------------------------------------------

      def start_diagnosis
        run(Application::Workshop::StartDiagnosis)
      end

      def send_quote
        run(Application::Workshop::SendQuote, diagnosis: params[:diagnosis])
      end

      def approve_quote
        # The only command that needs a second repository: approving deducts
        # stock in the same transaction.
        result = Application::Workshop::ApproveQuote.call(
          orders: order_repository, parts: part_repository, id: params[:id]
        )

        respond_with(result) { |order| serialize(order) }
      end

      def reject_quote
        run_releasing(Application::Workshop::RejectQuote)
      end

      def complete
        run(Application::Workshop::CompleteWork)
      end

      def deliver
        run(Application::Workshop::DeliverVehicle)
      end

      def cancel
        run_releasing(Application::Workshop::CancelServiceOrder)
      end

      private

      def run(use_case, **arguments)
        result = use_case.call(repository: order_repository, id: params[:id], **arguments)
        respond_with(result) { |order| serialize(order) }
      end

      # Rejection and cancellation release the order's reserved parts, so they
      # need the parts repository and the same two-context shape as approval.
      def run_releasing(use_case)
        result = use_case.call(
          orders: order_repository, parts: part_repository,
          id: params[:id], reason: params[:reason]
        )
        respond_with(result) { |order| serialize(order) }
      end

      def item_params
        params.require(:item).permit(:service_id, :part_id, :quantity)
      end

      def order_repository
        @order_repository ||= Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new
      end

      def part_repository
        @part_repository ||= Infrastructure::Persistence::Repositories::PartsInActiveRecord.new
      end

      def service_repository
        @service_repository ||= Infrastructure::Persistence::Repositories::ServicesInActiveRecord.new
      end

      def vehicle_repository
        @vehicle_repository ||= Infrastructure::Persistence::Repositories::VehiclesInActiveRecord.new
      end

      def customer_repository
        @customer_repository ||= Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new
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
