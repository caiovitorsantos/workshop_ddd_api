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
        result = Application::Registry::RegisterCustomer.call(
          repository: repository,
          tax_id: customer_params[:tax_id],
          name: customer_params[:name],
          email: customer_params[:email],
          phone: customer_params[:phone]
        )

        respond_with(result, success: :created) { |customer| serialize(customer) }
      end

      def update
        customer = repository.find(params[:id])
        return render_error("customer not found", :not_found) unless customer

        updated = customer.update_contact(
          name: customer_params.fetch(:name, customer.name),
          email: customer_params.fetch(:email, customer.email),
          phone: customer_params.fetch(:phone, customer.phone)
        )

        render json: serialize(repository.save(updated))
      rescue Domain::Shared::Errors::Base => e
        render_error(e.message, :unprocessable_entity)
      end

      def destroy
        repository.delete(params[:id])
        head :no_content
      rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
        render_error("customer still has vehicles attached", :conflict)
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new
      end

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
