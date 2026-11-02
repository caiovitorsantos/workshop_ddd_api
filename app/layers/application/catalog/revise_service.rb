module Application
  module Catalog
    # Use case: change what a catalog service is called, costs or takes.
    #
    # Orders already quoted keep the price they were quoted at — their lines
    # copied it when the service was added — so a revision only affects
    # orders from here on.
    class ReviseService < Application::Shared::UseCase
      def initialize(services:)
        @services = services
      end

      private

      attr_reader :services

      # `changes` holds only the attributes the caller sent. The price arrives
      # as a plain amount and becomes Money here, at the edge of the domain.
      def perform(id:, **changes)
        service = services.find(id)
        raise Domain::Shared::Errors::NotFound, "service #{id} not found" if service.nil?

        changes[:price] = Domain::Shared::Money.from_amount(changes[:price]) if changes.key?(:price)

        services.save(service.revise(**changes))
      end
    end
  end
end
