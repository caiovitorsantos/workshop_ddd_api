module Api
  module V1
    # Vehicle CRUD.
    class VehiclesController < BaseController
      def index
        # Nested under a customer when the route supplies one; otherwise the
        # whole fleet is not a listing anyone has asked for, so we require it.
        return render_error("customer_id is required", :bad_request) if params[:customer_id].blank?

        vehicles = repository.list_for_customer(params[:customer_id])

        render json: { data: vehicles.map { |v| serialize(v) } }
      end

      def show
        vehicle = repository.find(params[:id])
        return render_error("vehicle not found", :not_found) unless vehicle

        render json: serialize(vehicle)
      end

      def create
        result = Application::Registry::RegisterVehicle.call(
          vehicles: repository, customers: customer_repository,
          customer_id: params[:customer_id] || vehicle_params[:customer_id],
          plate: vehicle_params[:plate],
          make: vehicle_params[:make],
          model: vehicle_params[:model],
          year: vehicle_params[:year]
        )

        respond_with(result, success: :created) { |vehicle| serialize(vehicle) }
      end

      def update
        vehicle = repository.find(params[:id])
        return render_error("vehicle not found", :not_found) unless vehicle

        corrected = vehicle.correct_details(
          make: vehicle_params.fetch(:make, vehicle.make),
          model: vehicle_params.fetch(:model, vehicle.model),
          year: vehicle_params.fetch(:year, vehicle.year)
        )

        render json: serialize(repository.save(corrected))
      rescue Domain::Shared::Errors::Base => e
        render_error(e.message, :unprocessable_entity)
      end

      def destroy
        repository.delete(params[:id])
        head :no_content
      rescue ActiveRecord::InvalidForeignKey
        render_error("vehicle has service orders attached", :conflict)
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::VehiclesInActiveRecord.new
      end

      def customer_repository
        @customer_repository ||= Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new
      end

      def vehicle_params
        params.require(:vehicle).permit(:plate, :make, :model, :year, :customer_id)
      end

      def serialize(vehicle)
        {
          id: vehicle.id,
          plate: vehicle.plate.formatted,
          make: vehicle.make,
          model: vehicle.model,
          year: vehicle.year,
          customer_id: vehicle.customer_id,
          description: vehicle.description
        }
      end
    end
  end
end
