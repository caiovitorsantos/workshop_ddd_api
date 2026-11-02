module Application
  module Registry
    # Use case: remove a vehicle. Refused (Errors::InUse) once it has service
    # orders — those are history and must keep pointing at it.
    class RemoveVehicle < Application::Shared::UseCase
      def initialize(vehicles:)
        @vehicles = vehicles
      end

      private

      attr_reader :vehicles

      def perform(id:) = vehicles.delete(id)
    end
  end
end
