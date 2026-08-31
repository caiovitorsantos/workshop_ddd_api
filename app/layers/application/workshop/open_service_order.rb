module Application
  module Workshop
    # Use case: open a service order for a vehicle already on the books.
    #
    # This is **pivotal event 1** (PLANO_TECH_CHALLENGE.md §2.5): the point where
    # the conversation stops being about people and cars and starts being about
    # work to be done.
    class OpenServiceOrder < Application::Shared::UseCase
      def initialize(orders:, vehicles:, customers:, vehicle_id:)
        @orders = orders
        @vehicles = vehicles
        @customers = customers
        @vehicle_id = vehicle_id
      end

      private

      attr_reader :orders, :vehicles, :customers, :vehicle_id

      def perform
        vehicle = vehicles.find(vehicle_id)
        raise Domain::Shared::Errors::NotFound, "vehicle #{vehicle_id} not found" if vehicle.nil?

        # The order carries the customer id directly, rather than reaching
        # through the vehicle every time it needs to know whose car this is.
        # Ownership can change later; the order records who brought it in.
        customer = customers.find(vehicle.customer_id)
        raise Domain::Shared::Errors::NotFound, "customer of the vehicle not found" if customer.nil?

        order = Domain::Workshop::ServiceOrder.open(
          number: orders.next_number,
          customer_id: customer.id,
          vehicle_id: vehicle.id
        )

        orders.save(order)
      end
    end
  end
end
