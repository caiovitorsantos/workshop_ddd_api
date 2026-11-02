module Api
  module V1
    # Customer CRUD. Reference vertical slice for the interface layer: take
    # params, call the use case, serialize the result. Nothing beyond that.
    class CustomersController < BaseController
      def index
        customers, total = repository.list(page: page, per_page: per_page, query: params[:q])

        render json: {
          data: customers.map { |c| serialize(c) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def show
        customer = repository.find(params[:id])
        return render_error("customer not found", :not_found) unless customer

        render json: serialize(customer)
      end

      def create
        result = container.register_customer.call(
          tax_id: customer_params[:tax_id],
          name: customer_params[:name],
          email: customer_params[:email],
          phone: customer_params[:phone]
        )

        respond_with(result, success: :created) { |customer| serialize(customer) }
      end

      # `tax_id` is not among the changes passed on: it is the customer's
      # natural identity, and the spec proves a PATCH ignores it.
      def update
        result = container.update_customer_contact.call(
          id: params[:id], **changes_from(customer_params, :name, :email, :phone)
        )

        respond_with(result) { |customer| serialize(customer) }
      end

      def destroy
        respond_with(container.remove_customer.call(id: params[:id]), success: :no_content)
      end

      private

      def repository = container.customers

      def customer_params
        params.require(:customer).permit(:tax_id, :name, :email, :phone)
      end

      def serialize(customer)
        {
          id: customer.id,
          tax_id: customer.tax_id.formatted,
          tax_id_kind: customer.tax_id.kind,
          name: customer.name,
          email: customer.email,
          phone: customer.phone
        }
      end
    end
  end
end
