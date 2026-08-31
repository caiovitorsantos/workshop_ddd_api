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
        result = Application::Catalog::RegisterService.call(
          services: repository,
          name: service_params[:name],
          price: service_params[:price],
          description: service_params[:description],
          estimated_minutes: service_params[:estimated_minutes]
        )

        respond_with(result, success: :created) { |service| serialize(service) }
      end

      def update
        service = repository.find(params[:id])
        return render_error("service not found", :not_found) unless service

        revised = service.revise(
          name: service_params.fetch(:name, service.name),
          description: service_params.fetch(:description, service.description),
          price: price_or(service.price),
          estimated_minutes: service_params.fetch(:estimated_minutes, service.estimated_minutes),
          active: service_params.fetch(:active, service.active?)
        )

        render json: serialize(repository.save(revised))
      rescue Domain::Shared::Errors::Base => e
        render_error(e.message, :unprocessable_entity)
      end

      # Retiring beats deleting when the service has history: order items keep
      # their own copy of the name and price, so the past stays readable.
      def retire
        service = repository.find(params[:id])
        return render_error("service not found", :not_found) unless service

        render json: serialize(repository.save(service.retire))
      end

      def destroy
        repository.delete(params[:id])
        head :no_content
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ServicesInActiveRecord.new
      end

      def service_params
        params.require(:service).permit(:name, :description, :price, :estimated_minutes, :active)
      end

      def price_or(current)
        return current unless service_params.key?(:price)

        Domain::Shared::Money.from_amount(service_params[:price])
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
