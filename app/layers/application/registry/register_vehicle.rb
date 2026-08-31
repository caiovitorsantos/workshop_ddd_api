module Application
  module Registry
    # Use case: put a vehicle on the books, under an existing customer.
    class RegisterVehicle < Application::Shared::UseCase
      def initialize(vehicles:, customers:, customer_id:, plate:, make:, model:, year:)
        @vehicles = vehicles
        @customers = customers
        @customer_id = customer_id
        @plate = plate
        @make = make
        @model = model
        @year = year
      end

      private

      attr_reader :vehicles, :customers, :customer_id, :plate, :make, :model, :year

      def perform
        # The value object validates the plate, so a malformed one never reaches
        # the database.
        registration = Domain::Registry::LicensePlate.parse(plate)

        if vehicles.find_by_plate(registration)
          raise Domain::Shared::Errors::AlreadyExists,
                "a vehicle with plate #{registration.formatted} is already registered"
        end

        unless customers.find(customer_id)
          raise Domain::Shared::Errors::NotFound, "customer #{customer_id} not found"
        end

        vehicles.save(
          Domain::Registry::Vehicle.new(
            plate: registration, make: make, model: model,
            year: year, customer_id: customer_id
          )
        )
      end
    end
  end
end
