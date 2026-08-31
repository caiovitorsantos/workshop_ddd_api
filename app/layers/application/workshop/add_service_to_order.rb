module Application
  module Workshop
    # Use case: add a catalogued service to an order being assembled.
    #
    # The price is read from the Catalog here and **copied into the item**. From
    # that moment the order owns its own number: a later price change in the
    # catalog cannot rewrite a quote the customer has already seen.
    class AddServiceToOrder < Application::Shared::UseCase
      def initialize(orders:, services:, id:, service_id:, quantity: 1)
        @orders = orders
        @services = services
        @id = id
        @service_id = service_id
        @quantity = quantity
      end

      private

      attr_reader :orders, :services, :id, :service_id, :quantity

      def perform
        order = orders.find(id)
        raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

        service = services.find(service_id)
        raise Domain::Shared::Errors::NotFound, "service #{service_id} not found" if service.nil?

        unless service.active?
          raise Domain::Shared::Errors::BusinessRuleViolation,
                "service '#{service.name}' is no longer offered"
        end

        order.add_service(
          service_id: service.id,
          description: service.name,
          unit_price: service.price,
          quantity: quantity
        )

        orders.save(order)
      end
    end
  end
end
