module Api
  module V1
    # Output adapter: how the API shows a Domain::Registry::Vehicle.
    module VehiclePresenter
      def self.call(vehicle)
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
