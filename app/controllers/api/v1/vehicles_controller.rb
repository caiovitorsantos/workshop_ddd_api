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
        result = container.register_vehicle.call(
          customer_id: params[:customer_id] || vehicle_params[:customer_id],
          plate: vehicle_params[:plate],
          make: vehicle_params[:make],
          model: vehicle_params[:model],
          year: vehicle_params[:year]
        )

        respond_with(result, success: :created) { |vehicle| serialize(vehicle) }
      end

      # The plate is not among the changes passed on — it is the vehicle's
      # natural identity.
      def update
        result = container.correct_vehicle_details.call(
          id: params[:id], **changes_from(vehicle_params, :make, :model, :year)
        )

        respond_with(result) { |vehicle| serialize(vehicle) }
      end

      def destroy
        respond_with(container.remove_vehicle.call(id: params[:id]), success: :no_content)
      end

      private

      def repository = container.vehicles

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
