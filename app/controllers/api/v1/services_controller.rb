module Api
  module V1
    # Catalog of services the workshop offers.
    class ServicesController < BaseController
      def index
        # Defaults to active only: the catalog is what you can order today.
        # Pass ?include_retired=true to see withdrawn entries as well.
        services, total = repository.list(
          page: page, per_page: per_page, active_only: params[:include_retired].blank?
        )

        render json: {
          data: services.map { |s| serialize(s) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def show
        service = repository.find(params[:id])
        return render_error("service not found", :not_found) unless service

        render json: serialize(service)
      end

      def create
        result = container.register_service.call(
          name: service_params[:name],
          price: service_params[:price],
          description: service_params[:description],
          estimated_minutes: service_params[:estimated_minutes]
        )

        respond_with(result, success: :created) { |service| serialize(service) }
      end

      def update
        result = container.revise_service.call(
          id: params[:id],
          **changes_from(service_params, :name, :description, :price, :estimated_minutes, :active)
        )

        respond_with(result) { |service| serialize(service) }
      end

      # Retiring beats deleting when the service has history: order items keep
      # their own copy of the name and price, so the past stays readable.
      def retire
        respond_with(container.retire_service.call(id: params[:id])) { |service| serialize(service) }
      end

      def destroy
        respond_with(container.remove_service.call(id: params[:id]), success: :no_content)
      end

      private

      def repository = container.services

      def service_params
        params.require(:service).permit(:name, :description, :price, :estimated_minutes, :active)
      end

      def serialize(service)
        {
          id: service.id,
          name: service.name,
          description: service.description,
          price: service.price.amount.to_s("F"),
          estimated_minutes: service.estimated_minutes,
          active: service.active?
        }
      end
    end
  end
end
