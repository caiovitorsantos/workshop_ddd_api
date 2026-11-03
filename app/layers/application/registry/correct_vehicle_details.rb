module Application
  module Registry
    # Use case: fix a vehicle's make, model or year.
    #
    # The plate is the vehicle's natural identity and is not among the things
    # that can be corrected; neither is the owner.
    class CorrectVehicleDetails < Application::Shared::UseCase
      def initialize(vehicles:)
        @vehicles = vehicles
      end

      private

      attr_reader :vehicles

      # `changes` holds only the attributes the caller sent (make, model, year).
      def perform(id:, **changes)
        vehicle = vehicles.find(id)
        raise Domain::Shared::Errors::NotFound, "vehicle #{id} not found" if vehicle.nil?

        vehicles.save(vehicle.correct_details(**changes))
      end
    end
  end
end
