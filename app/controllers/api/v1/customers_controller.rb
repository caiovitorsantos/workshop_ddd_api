module Api
  module V1
    # Customer CRUD. Reference vertical slice for the interface layer: take
    # params, call the use case, present the result. Nothing beyond that.
    class CustomersController < BaseController
      def index
        customers, total = repository.list(page: page, per_page: per_page, query: params[:q])

        render_page(customers, total, with: CustomerPresenter)
      end

      def show
        render_found(repository.find(params[:id]), with: CustomerPresenter, missing: "customer")
      end

      def create
        result = container.register_customer.call(
          tax_id: customer_params[:tax_id],
          name: customer_params[:name],
          email: customer_params[:email],
          phone: customer_params[:phone]
        )

        respond_with(result, with: CustomerPresenter, success: :created)
      end

      # `tax_id` is not among the changes passed on: it is the customer's
      # natural identity, and the spec proves a PATCH ignores it.
      def update
        result = container.update_customer_contact.call(
          id: params[:id], **changes_from(customer_params, :name, :email, :phone)
        )

        respond_with(result, with: CustomerPresenter)
      end

      def destroy
        respond_with(container.remove_customer.call(id: params[:id]), success: :no_content)
      end

      private

      def repository = container.customers

      def customer_params
        params.require(:customer).permit(:tax_id, :name, :email, :phone)
      end
    end
  end
end
