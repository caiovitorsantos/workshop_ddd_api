module Application
  module Registry
    # Use case: the vehicle changed owner.
    #
    # Its own command rather than a field on update, for the same reason status
    # changes are commands: "this car now belongs to someone else" is a business
    # event with consequences (whose history it joins, who gets quoted), not an
    # attribute edit.
    class TransferVehicle < Application::Shared::UseCase
      def initialize(vehicles:, customers:, id:, customer_id:)
        @vehicles = vehicles
        @customers = customers
        @id = id
        @customer_id = customer_id
      end

      private

      attr_reader :vehicles, :customers, :id, :customer_id

      def perform
        vehicle = vehicles.find(id)
        raise Domain::Shared::Errors::NotFound, "vehicle #{id} not found" if vehicle.nil?

        unless customers.find(customer_id)
          raise Domain::Shared::Errors::NotFound, "customer #{customer_id} not found"
        end

        vehicles.save(vehicle.transfer_to(customer_id))
      end
    end
  end
end
